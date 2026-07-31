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
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else { continue }

            let segStart = max(seg.startDate, startDate)
            let segEnd = min(seg.endDate, endDate)
            let offsetInFile = segStart.timeIntervalSince(seg.startDate)
            var rangeDuration = segEnd.timeIntervalSince(segStart)

            let assetDuration = try await asset.load(.duration).seconds
            if assetDuration.isFinite, assetDuration > 0 {
                let available = max(0, assetDuration - offsetInFile)
                rangeDuration = min(rangeDuration, available)
            }
            guard rangeDuration > 0 else { continue }

            let rangeStart = CMTime(seconds: offsetInFile, preferredTimescale: 16_000)
            let rangeDurationTime = CMTime(seconds: rangeDuration, preferredTimescale: 16_000)
            let timeRange = CMTimeRange(start: rangeStart, duration: rangeDurationTime)

            try compTrack.insertTimeRange(timeRange, of: track, at: insertCursor)
            insertCursor = CMTimeAdd(insertCursor, rangeDurationTime)
        }

        guard insertCursor.seconds > 0 else { throw ExportError.noSegments }

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


