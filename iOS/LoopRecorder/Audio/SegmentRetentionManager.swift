import Foundation

final class SegmentRetentionManager {
    let retentionWindow: TimeInterval

    init(retentionWindow: TimeInterval) {
        self.retentionWindow = retentionWindow
    }

    func applyRetention(segments: inout [RecordingSegment], protectedURLs: Set<URL>) {
        let cutoff = Date().addingTimeInterval(-retentionWindow)
        var kept: [RecordingSegment] = []
        for seg in segments.sorted(by: { $0.startDate < $1.startDate }) {
            if seg.endDate >= cutoff || protectedURLs.contains(seg.url) {
                kept.append(seg)
            } else {
                try? FileManager.default.removeItem(at: seg.url)
            }
        }
        segments = kept
    }

    /// Removes segment files on disk that are older than the retention window.
    /// Catches orphans left behind when recording stops before the first segment rotation.
    func purgeStaleSegmentFiles(in directory: URL, protectedURLs: Set<URL>) {
        let cutoff = Date().addingTimeInterval(-retentionWindow)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls where url.pathExtension == "m4a" {
            guard !protectedURLs.contains(url) else { continue }
            let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            if modDate < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}


