import Foundation

/// Owns the on-device copy of imported audio files.
///
/// A URL returned by the document picker points outside the app sandbox and is
/// reachable only while its security scope is open. Every import is therefore
/// copied into the app container right away: later stages (analysis, slicing,
/// export) work with the copy and never depend on the original file.
///
/// The type is an actor so file IO never runs on the main thread.
actor SampleStorage {
    enum Failure: LocalizedError {
        case copyFailed(name: String, underlying: Error)

        var errorDescription: String? {
            switch self {
            case .copyFailed(let name, _):
                return "Could not copy \(name). The file may have been moved, or it is not downloaded from iCloud yet."
            }
        }
    }

    private let directory: URL

    /// - Parameter directory: storage location; defaults to `Application Support/Imported`.
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Imported", directoryHint: .isDirectory)
    }

    /// Copies the file behind a picker URL into storage and returns the stored copy.
    func importFile(at sourceURL: URL) throws -> ImportedSample {
        try ensureDirectory()
        let id: UUID = .init()
        let fileExtension: String = sourceURL.pathExtension.lowercased()
        let fileName: String = fileExtension.isEmpty ? id.uuidString : "\(id.uuidString).\(fileExtension)"
        let destination: URL = directory.appending(path: fileName)
        let isScoped: Bool = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        let copyFailure: Error? = copyCoordinated(from: sourceURL, to: destination)
        if let copyFailure {
            throw Failure.copyFailed(name: sourceURL.lastPathComponent, underlying: copyFailure)
        }
        return .init(
            id: id,
            url: destination,
            displayName: sourceURL.lastPathComponent,
            importedAt: .now
        )
    }

    func remove(_ sample: ImportedSample) throws {
        guard FileManager.default.fileExists(atPath: sample.url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: sample.url)
    }

    /// Copies through `NSFileCoordinator` because files backed by iCloud or a
    /// third-party provider may be dehydrated and need coordinated access.
    private func copyCoordinated(from source: URL, to destination: URL) -> Error? {
        let coordinator: NSFileCoordinator = .init()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinationError) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destination)
            } catch {
                copyError = error
            }
        }
        return coordinationError ?? copyError
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Imported samples are recoverable, so they should not inflate iCloud backups.
        var mutableDirectory: URL = directory
        var values: URLResourceValues = .init()
        values.isExcludedFromBackup = true
        try? mutableDirectory.setResourceValues(values)
    }
}
