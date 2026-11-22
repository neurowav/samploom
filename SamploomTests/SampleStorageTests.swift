import Foundation
import Testing

@testable import Samploom

@Suite("SampleStorage")
struct SampleStorageTests {
    @Test("Import copies the picked file into storage")
    func importCopiesFile() async throws {
        let source = try makeSourceFile(named: "loop 128BPM.wav", contents: "RIFF-data")
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }

        let sample = try await storage.storage.importFile(at: source)

        #expect(sample.displayName == "loop 128BPM.wav")
        #expect(sample.url != source)
        #expect(FileManager.default.fileExists(atPath: sample.url.path(percentEncoded: false)))
        #expect(try Data(contentsOf: sample.url) == Data("RIFF-data".utf8))
    }

    @Test("Stored copy keeps the original file extension")
    func importKeepsExtension() async throws {
        let source = try makeSourceFile(named: "kick.aiff", contents: "FORM")
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }

        let sample = try await storage.storage.importFile(at: source)

        #expect(sample.url.pathExtension == "aiff")
    }

    @Test("Remove deletes the stored copy")
    func removeDeletesCopy() async throws {
        let source = try makeSourceFile(named: "hat.wav", contents: "RIFF")
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }

        let sample = try await storage.storage.importFile(at: source)
        try await storage.storage.remove(sample)

        #expect(FileManager.default.fileExists(atPath: sample.url.path(percentEncoded: false)) == false)
    }

    @Test("Removing an already deleted copy does not throw")
    func removeIsIdempotent() async throws {
        let source = try makeSourceFile(named: "snare.wav", contents: "RIFF")
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }

        let sample = try await storage.storage.importFile(at: source)
        try await storage.storage.remove(sample)

        await #expect(throws: Never.self) {
            try await storage.storage.remove(sample)
        }
    }

    @Test("Importing a missing file fails with a copy error")
    func importMissingFileFails() async throws {
        let storage = try makeStorage()
        defer { try? FileManager.default.removeItem(at: storage.directory) }

        let missing = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")

        await #expect(throws: SampleStorage.Failure.self) {
            try await storage.storage.importFile(at: missing)
        }
    }

    private func makeStorage() throws -> (storage: SampleStorage, directory: URL) {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        return (SampleStorage(directory: directory), directory)
    }

    private func makeSourceFile(named name: String, contents: String) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try Data(contents.utf8).write(to: url)
        return url
    }
}
