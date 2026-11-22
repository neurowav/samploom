import Foundation
import Testing

@testable import Samploom

@MainActor
@Suite("ImportViewModel")
struct ImportViewModelTests {
    @Test("Picking a file moves the state to imported")
    func successSetImportedContent() async throws {
        let source = try makeSourceFile(named: "break 174BPM.wav")
        let testCase = makeViewModel()
        defer { try? FileManager.default.removeItem(at: testCase.directory) }

        testCase.model.handlePickedFile(.success(source))
        await waitUntilIdle(testCase.model)

        guard case .imported(let sample) = testCase.model.content else {
            Issue.record("Expected imported content, got \(testCase.model.content)")
            return
        }
        #expect(sample.displayName == "break 174BPM.wav")
        #expect(testCase.model.errorMessage == nil)
    }

    @Test("Replacing a sample removes the previous copy")
    func replaceRemovesPreviousCopy() async throws {
        let first = try makeSourceFile(named: "first.wav")
        let second = try makeSourceFile(named: "second.wav")
        let testCase = makeViewModel()
        defer { try? FileManager.default.removeItem(at: testCase.directory) }

        testCase.model.handlePickedFile(.success(first))
        await waitUntilIdle(testCase.model)
        guard case .imported(let firstSample) = testCase.model.content else {
            Issue.record("Expected the first sample to be imported")
            return
        }

        testCase.model.handlePickedFile(.success(second))
        await waitUntilIdle(testCase.model)

        #expect(FileManager.default.fileExists(atPath: firstSample.url.path(percentEncoded: false)) == false)
    }

    @Test("A failed import reports the error and keeps the previous state")
    func failureKeepsPreviousContent() async throws {
        let testCase = makeViewModel()
        defer { try? FileManager.default.removeItem(at: testCase.directory) }

        let missing = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        testCase.model.handlePickedFile(.success(missing))
        await waitUntilIdle(testCase.model)

        #expect(testCase.model.content == .empty)
        #expect(testCase.model.errorMessage != nil)
    }

    @Test("A cancelled picker does not change the state")
    func cancellationIsSilent() {
        let testCase = makeViewModel()

        testCase.model.handlePickedFile(.failure(CocoaError(.userCancelled)))

        #expect(testCase.model.content == .empty)
        #expect(testCase.model.errorMessage == nil)
    }

    private func makeViewModel() -> (model: ImportViewModel, directory: URL) {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        return (ImportViewModel(storage: SampleStorage(directory: directory)), directory)
    }

    private func makeSourceFile(named name: String) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try Data("RIFF".utf8).write(to: url)
        return url
    }

    /// Import runs in a detached task; poll until the state leaves `.importing`.
    private func waitUntilIdle(_ model: ImportViewModel) async {
        for _ in 0..<100 {
            if model.content != .importing { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
