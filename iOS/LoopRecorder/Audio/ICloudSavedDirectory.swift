import Foundation

enum SavedClipDirectoryError: LocalizedError {
    case storageUnavailable

    var errorDescription: String? {
        "Could not access storage. Sign in to iCloud and enable iCloud Drive in Settings, then try again."
    }
}

enum SavedClipDirectory {
    static let containerIdentifier = "iCloud.com.extraram.LoopRecorder"
    private static let localFolderName = "SavedClips"

    /// Shown in the app — Files app path on device.
    static var displayPath: String {
        usesICloudStorage ? "iCloud/Recall Audio" : "On My iPhone/Recall Audio"
    }

    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private static var usesICloudStorage: Bool {
        isICloudAvailable && FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) != nil
    }

    static func resolveSavedDirectory() throws -> URL {
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerIdentifier) {
            let directory = containerURL.appendingPathComponent("Documents", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }

        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents.appendingPathComponent(localFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
