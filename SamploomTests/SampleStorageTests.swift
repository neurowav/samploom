import Foundation
import Testing

@testable import Samploom

@Suite("SampleStorage")
struct SampleStorageTests {
    @Test("Import copies the picked file into storage")
    func importCopiesFile() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(named: "loop 128BPM.wav", contents: "RIFF-data")
        let sample: ImportedSample = try await harness.storage.importFile(at: source)
        #expect(sample.displayName == "loop 128BPM.wav")
        #expect(sample.url != source)
        #expect(FileManager.default.fileExists(atPath: sample.url.path(percentEncoded: false)))
        #expect(try Data(contentsOf: sample.url) == Data("RIFF-data".utf8))
    }

    @Test("Stored copy keeps the original file extension")
    func importKeepsExtension() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(named: "kick.aiff", contents: "FORM")
        let sample: ImportedSample = try await harness.storage.importFile(at: source)
        #expect(sample.url.pathExtension == "aiff")
    }

    @Test("Remove deletes the stored copy")
    func removeDeletesCopy() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(named: "hat.wav", contents: "RIFF")
        let sample: ImportedSample = try await harness.storage.importFile(at: source)
        try await harness.storage.remove(sample)
        #expect(FileManager.default.fileExists(atPath: sample.url.path(percentEncoded: false)) == false)
    }

    @Test("Removing an already deleted copy does not throw")
    func removeIsIdempotent() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(named: "snare.wav", contents: "RIFF")
        let sample: ImportedSample = try await harness.storage.importFile(at: source)
        try await harness.storage.remove(sample)
        await #expect(throws: Never.self) {
            try await harness.storage.remove(sample)
        }
    }

    @Test("Importing a missing file fails with a copy error")
    func importMissingFileFails() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let missing: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        await #expect(throws: SampleStorage.Failure.self) {
            try await harness.storage.importFile(at: missing)
        }
    }
}

private struct Harness {
    let storage: SampleStorage
    let root: URL

    init() {
        let root: URL = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        self.root = root
        self.storage = .init(directory: root.appending(path: "Imported", directoryHint: .isDirectory))
    }

    func makeSourceFile(named name: String, contents: String) throws -> URL {
        let directory: URL = root.appending(path: "Source", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url: URL = directory.appending(path: name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
