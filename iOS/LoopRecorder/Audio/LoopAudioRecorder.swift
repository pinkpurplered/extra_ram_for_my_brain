import Foundation
import AVFoundation

@MainActor
final class LoopAudioRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var lastSavedURL: URL?
    @Published var lastError: String?

    private let audioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var segmentTimer: Timer?

    private(set) var segments: [RecordingSegment] = []
    private var protectedURLs: Set<URL> = []

    // Configurable
    let segmentDurationSeconds: TimeInterval = 60
    let retentionWindow: TimeInterval = 1 * 60 * 60 // 1 hour

    // Voice-optimized encoding (lower CPU and battery than music-quality settings)
    private let sampleRate: Double = 16_000
    private let encoderBitRate: Int = 32_000

    private lazy var retentionManager = SegmentRetentionManager(retentionWindow: retentionWindow)

    func prepare() {
        try? SavedClipDirectory.resolveSavedDirectory()
    }

    func start() {
        Task { @MainActor in
            lastError = nil
            do {
                let granted = await requestMicrophonePermission()
                guard granted else {
                    lastError = "Microphone access is required to record."
                    return
                }
                try configureSession()
                try startNewSegment()
                isRecording = true
                scheduleNextSegment()
            } catch {
                isRecording = false
                lastError = "Could not start recording: \(error.localizedDescription)"
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        finalizeLastSegment()
        segmentTimer?.invalidate()
        segmentTimer = nil
        isRecording = false
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.mixWithOthers])
        try audioSession.setActive(true, options: [])
    }

    private func scheduleNextSegment() {
        segmentTimer?.invalidate()
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDurationSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.rotateSegment()
            }
        }
        RunLoop.main.add(segmentTimer!, forMode: .common)
    }

    private func rotateSegment() {
        recorder?.stop()
        recorder = nil
        finalizeLastSegment()
        try? startNewSegment()
        retentionManager.applyRetention(segments: &segments, protectedURLs: protectedURLs)
    }

    private func finalizeLastSegment() {
        guard let lastIndex = segments.indices.last else { return }
        let last = segments[lastIndex]
        let actualDuration = Date().timeIntervalSince(last.startDate)
        guard actualDuration > 0 else { return }
        segments[lastIndex] = RecordingSegment(
            url: last.url,
            startDate: last.startDate,
            duration: actualDuration
        )
    }

    private func recordingsDirectory() throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Segments", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }


    private func newSegmentURL() throws -> URL {
        let dir = try recordingsDirectory()
        let formatter = ISO8601DateFormatter()
        let name = "segment_\(formatter.string(from: Date())).m4a"
        return dir.appendingPathComponent(name)
    }

    private func startNewSegment() throws {
        let url = try newSegmentURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: encoderBitRate,
            AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = false
        recorder?.record()

        let seg = RecordingSegment(url: url, startDate: Date(), duration: segmentDurationSeconds)
        segments.append(seg)
    }

    func saveLast(minutes: Int) async throws -> URL {
        let wasRecording = isRecording
        if wasRecording {
            // Close the in-progress segment so AVFoundation can read the file.
            recorder?.stop()
            recorder = nil
            segmentTimer?.invalidate()
            segmentTimer = nil
            finalizeLastSegment()
        }

        defer {
            if wasRecording {
                do {
                    try startNewSegment()
                    scheduleNextSegment()
                } catch {
                    isRecording = false
                    lastError = "Could not resume recording: \(error.localizedDescription)"
                }
            }
        }

        let end = Date()
        let start = end.addingTimeInterval(TimeInterval(-minutes) * 60)
        let savedDir = try SavedClipDirectory.resolveSavedDirectory()
        let outURL = savedDir.appendingPathComponent(outputFileName(suffixMinutes: minutes))
        let url = try await AudioCompositionExporter.export(segments: segments, from: start, to: end, to: outURL)
        protectedURLs.insert(url)
        lastSavedURL = url
        return url
    }

    private func outputFileName(suffixMinutes: Int) -> String {
        let formatter = ISO8601DateFormatter()
        let stamp = formatter.string(from: Date())
        return "saved_\(suffixMinutes)m_\(stamp).m4a"
    }
}


