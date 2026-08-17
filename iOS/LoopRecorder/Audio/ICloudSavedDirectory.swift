import Foundation

enum SavedClipDirectory {
    static let folderName = "extraramformybrain"

    /// Shown in the app — Files app path on device.
    static var displayPath: String {
        "On My iPhone/Recall Audio/\(folderName)"
    }

    static func resolveSavedDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
