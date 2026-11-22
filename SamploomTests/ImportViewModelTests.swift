import Foundation
import Testing

@testable import Samploom

@MainActor
@Suite("ImportViewModel")
struct ImportViewModelTests {
    @Test("Picking a file moves the state to imported")
    func successSetsImportedContent() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(named: "break 174BPM.wav")
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilImported()
        guard case .imported(let sample) = harness.model.content else {
            Issue.record("Expected imported content, got \(harness.model.content)")
            return
        }
        #expect(sample.displayName == "break 174BPM.wav")
        #expect(harness.model.errorMessage == nil)
    }

    @Test("Replacing a sample removes the previous copy")
    func replaceRemovesPreviousCopy() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let first: URL = try harness.makeSourceFile(named: "first.wav")
        let second: URL = try harness.makeSourceFile(named: "second.wav")
        harness.model.handlePickedFile(.success(first))
        await harness.waitUntilImported()
        guard case .imported(let firstSample) = harness.model.content else {
            Issue.record("Expected the first sample to be imported")
            return
        }
        harness.model.handlePickedFile(.success(second))
        await harness.waitUntilImported()
        #expect(FileManager.default.fileExists(atPath: firstSample.url.path(percentEncoded: false)) == false)
    }

    @Test("A failed import reports the error and keeps the previous state")
    func failureKeepsPreviousContent() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let missing: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        harness.model.handlePickedFile(.success(missing))
        await harness.waitUntilImported()
        #expect(harness.model.content == .empty)
        #expect(harness.model.errorMessage != nil)
    }

    @Test("A cancelled picker does not change the state")
    func cancellationIsSilent() {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        harness.model.handlePickedFile(.failure(CocoaError(.userCancelled)))
        #expect(harness.model.content == .empty)
        #expect(harness.model.errorMessage == nil)
    }

    @Test("The grid follows the tempo detected in the file name")
    func gridFromFileNameTempo() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "loop_128BPM.wav",
            contents: WAVFixture.silence(seconds: 0.5)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilInspected()
        #expect(harness.model.grid?.secondsPerBar == 1.875)
        #expect(harness.model.info?.tempo?.source == .fileName)
    }
}

private struct Harness {
    let model: ImportViewModel
    let root: URL

    init() {
        let root: URL = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        self.root = root
        self.model = .init(
            storage: .init(directory: root.appending(path: "Imported", directoryHint: .isDirectory)),
            inspector: .init()
        )
    }

    func makeSourceFile(named name: String, contents: Data = Data("RIFF".utf8)) throws -> URL {
        let directory: URL = root.appending(path: "Source-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url: URL = directory.appending(path: name)
        try contents.write(to: url)
        return url
    }

    func waitUntilImported() async {
        for _ in 0..<200 {
            if model.content != .importing {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Inspection runs after the file is stored, so wait for its outcome too.
    func waitUntilInspected() async {
        await waitUntilImported()
        for _ in 0..<200 {
            if model.info != nil {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
