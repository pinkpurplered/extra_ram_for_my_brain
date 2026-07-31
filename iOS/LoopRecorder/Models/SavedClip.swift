import Foundation

enum SavedClipError: LocalizedError {
    case invalidName
    case nameAlreadyExists
    case renameFailed

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter a valid name."
        case .nameAlreadyExists:
            return "A recording with that name already exists."
        case .renameFailed:
            return "Couldn't rename the recording."
        }
    }
}

struct SavedClip: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let requestedMinutes: Int?

    var id: URL { url }

    var fileName: String { url.lastPathComponent }

    var displayTitle: String {
        if let requestedMinutes {
            return "\(requestedMinutes) min clip"
        }
        return url.deletingPathExtension().lastPathComponent
    }

    var editableName: String { displayTitle }

    func delete() throws {
        try FileManager.default.removeItem(at: url)
    }

    func rename(to newName: String) throws -> SavedClip {
        guard let sanitized = Self.sanitizedBaseName(newName) else {
            throw SavedClipError.invalidName
        }

        let currentBaseName = url.deletingPathExtension().lastPathComponent
        if sanitized == currentBaseName {
            return self
        }

        let destination = url.deletingLastPathComponent().appendingPathComponent("\(sanitized).m4a")
        if FileManager.default.fileExists(atPath: destination.path) {
            throw SavedClipError.nameAlreadyExists
        }

        try FileManager.default.moveItem(at: url, to: destination)
        guard let renamed = SavedClip(url: destination) else {
            throw SavedClipError.renameFailed
        }
        return renamed
    }

    static func sanitizedBaseName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        var sanitized = trimmed
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        while sanitized.hasPrefix(".") {
            sanitized.removeFirst()
        }

        return sanitized.isEmpty ? nil : sanitized
    }

    static func loadAll() throws -> [SavedClip] {
        let directory = try SavedClipDirectory.resolveSavedDirectory()
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "m4a" }

        let clips = urls.compactMap { SavedClip(url: $0) }
        return clips.sorted { $0.createdAt > $1.createdAt }
    }

    init?(url: URL) {
        self.url = url
        let name = url.deletingPathExtension().lastPathComponent

        if name.hasPrefix("saved_"), let minutes = Self.parseRequestedMinutes(from: name) {
            requestedMinutes = minutes
        } else {
            requestedMinutes = nil
        }

        if let parsedDate = Self.parseDate(from: name) {
            createdAt = parsedDate
        } else if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey]),
                  let date = values.contentModificationDate ?? values.creationDate {
            createdAt = date
        } else {
            createdAt = .distantPast
        }
    }

    private static func parseRequestedMinutes(from fileName: String) -> Int? {
        guard fileName.hasPrefix("saved_") else { return nil }
        let rest = fileName.dropFirst("saved_".count)
        guard let mIndex = rest.firstIndex(of: "m"), rest[..<mIndex].allSatisfy(\.isNumber) else {
            return nil
        }
        return Int(rest[..<mIndex])
    }

    private static func parseDate(from fileName: String) -> Date? {
        guard let underscore = fileName.lastIndex(of: "_") else { return nil }
        let stamp = String(fileName[fileName.index(after: underscore)...])
        return ISO8601DateFormatter().date(from: stamp)
    }
}
