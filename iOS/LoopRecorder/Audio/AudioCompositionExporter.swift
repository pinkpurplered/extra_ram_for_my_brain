import AVFoundation

enum ExportError: Error {
    case noSegments
    case compositionFailed
    case exportFailed
}

final class AudioCompositionExporter {
    static func export(segments: [RecordingSegment], from startDate: Date, to endDate: Date, to outputURL: URL) async throws -> URL {
        let relevant = segments
            .sorted(by: { $0.startDate < $1.startDate })
            .filter { $0.endDate > startDate && $0.startDate < endDate }
        guard !relevant.isEmpty else { throw ExportError.noSegments }

        let composition = AVMutableComposition()
        guard let compTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.compositionFailed
        }

        var insertCursor = CMTime.zero
        for seg in relevant {
            let asset = AVURLAsset(url: seg.url)
            guard let track = asset.tracks(withMediaType: .audio).first else { continue }

            let segStart = max(seg.startDate, startDate)
            let segEnd = min(seg.endDate, endDate)
            let rangeStart = CMTime(seconds: segStart.timeIntervalSince(seg.startDate), preferredTimescale: 44100)
            let rangeDuration = CMTime(seconds: segEnd.timeIntervalSince(segStart), preferredTimescale: 44100)
            let timeRange = CMTimeRange(start: rangeStart, duration: rangeDuration)

            try compTrack.insertTimeRange(timeRange, of: track, at: insertCursor)
            insertCursor = CMTimeAdd(insertCursor, rangeDuration)
        }

        try? FileManager.default.removeItem(at: outputURL)
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError.exportFailed
        }
        export.outputURL = outputURL
        export.outputFileType = .m4a

        return try await withCheckedThrowingContinuation { continuation in
            export.exportAsynchronously {
                if export.status == .completed, let url = export.outputURL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: export.error ?? ExportError.exportFailed)
                }
            }
        }
    }
}


