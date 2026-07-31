import Foundation

enum ClipFolderError: LocalizedError {
    case invalidName
    case nameAlreadyExists
    case notEmpty
    case renameFailed

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter a valid folder name."
        case .nameAlreadyExists:
            return "A folder with that name already exists."
        case .notEmpty:
            return "Move or delete recordings in this folder first."
        case .renameFailed:
            return "Couldn't rename the folder."
        }
    }
}

struct ClipFolder: Identifiable, Hashable {
    let url: URL

    var id: URL { url }
    var name: String { url.lastPathComponent }

    func clipCount() throws -> Int {
        try SavedClip.loadAll(in: url).count
    }

    func delete() throws {
        let clips = try SavedClip.loadAll(in: url)
        guard clips.isEmpty else {
            throw ClipFolderError.notEmpty
        }
        try FileManager.default.removeItem(at: url)
    }

    func rename(to newName: String) throws -> ClipFolder {
        guard let sanitized = SavedClip.sanitizedBaseName(newName) else {
            throw ClipFolderError.invalidName
        }

        if sanitized == name {
            return self
        }

        let parent = url.deletingLastPathComponent()
        let destination = parent.appendingPathComponent(sanitized, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            throw ClipFolderError.nameAlreadyExists
        }

        try FileManager.default.moveItem(at: url, to: destination)
        return ClipFolder(url: destination)
    }

    static func loadAll() throws -> [ClipFolder] {
        let root = try SavedClipDirectory.resolveSavedDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let folders = urls.compactMap { url -> ClipFolder? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else {
                return nil
            }
            return ClipFolder(url: url)
        }

        return folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func create(name: String) throws -> ClipFolder {
        guard let sanitized = SavedClip.sanitizedBaseName(name) else {
            throw ClipFolderError.invalidName
        }

        let root = try SavedClipDirectory.resolveSavedDirectory()
        let destination = root.appendingPathComponent(sanitized, isDirectory: true)
        if FileManager.default.fileExists(atPath: destination.path) {
            throw ClipFolderError.nameAlreadyExists
        }

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        return ClipFolder(url: destination)
    }
}
