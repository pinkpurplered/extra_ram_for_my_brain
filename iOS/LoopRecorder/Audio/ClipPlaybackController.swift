import AVFoundation
import Foundation

@MainActor
final class ClipPlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentClipURL: URL?
    @Published private(set) var isLoading = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    func load(_ url: URL) async {
        if currentClipURL == url, player != nil {
            return
        }

        stop()
        isLoading = true
        defer { isLoading = false }

        let asset = AVURLAsset(url: url)
        let loadedDuration = (try? await asset.load(.duration))?.seconds ?? 0
        duration = loadedDuration.isFinite ? loadedDuration : 0

        let item = AVPlayerItem(asset: asset)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        currentClipURL = url
        currentTime = 0
        isPlaying = false

        addObservers(to: newPlayer, item: item)
    }

    func togglePlayPause() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            activatePlaybackSession()
            player.play()
            isPlaying = true
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(0, time), duration)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 1_000))
        currentTime = clamped
    }

    func stop() {
        player?.pause()
        removeObservers()
        player = nil
        currentClipURL = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        isLoading = false
    }

    private func activatePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.mixWithOthers, .defaultToSpeaker])
        try? session.setActive(true)
    }

    private func addObservers(to player: AVPlayer, item: AVPlayerItem) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 1_000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                player.seek(to: .zero)
            }
        }
    }

    private func removeObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

}

private extension CMTime {
    var seconds: TimeInterval {
        CMTimeGetSeconds(self)
    }
}
