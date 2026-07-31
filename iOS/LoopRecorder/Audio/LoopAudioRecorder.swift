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

    private lazy var retentionManager = SegmentRetentionManager(retentionWindow: retentionWindow)

    func prepare() {
        // Nothing heavy on main thread yet; session configured on start
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
        segmentTimer?.invalidate()
        segmentTimer = nil
        isRecording = false
    }

    private func configureSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers])
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
        try? startNewSegment()
        retentionManager.applyRetention(segments: &segments, protectedURLs: protectedURLs)
    }

    private func recordingsDirectory() throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Segments", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func savedDirectory() throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Saved", isDirectory: true)
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
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.isMeteringEnabled = false
        recorder?.record()

        let seg = RecordingSegment(url: url, startDate: Date(), duration: segmentDurationSeconds)
        segments.append(seg)
    }

    func saveLast(minutes: Int) async throws -> URL {
        let end = Date()
        let start = end.addingTimeInterval(TimeInterval(-minutes) * 60)
        let outURL = try savedDirectory().appendingPathComponent(outputFileName(suffixMinutes: minutes))
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


