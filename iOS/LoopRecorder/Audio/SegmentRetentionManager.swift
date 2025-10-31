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
}


