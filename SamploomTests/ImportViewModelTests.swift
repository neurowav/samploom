import Foundation
import SamploomDomain
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

    @Test("A slice plan appears once the audio is decoded")
    func planForLoadedSample() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "loop_120BPM.wav",
            contents: WAVFixture.tone(seconds: 4, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilDecoded()
        let plan: SlicePlan = try #require(harness.model.plan)
        #expect(plan.starts.count == 4)
        #expect(plan.sliceLength == 2.0)
        #expect(Set(plan.starts).count == 1)
    }

    @Test("A silent sample gives an empty plan instead of empty slices")
    func silentSampleHasNoPlan() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "silence.wav",
            contents: WAVFixture.silence(seconds: 4)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilDecoded()
        #expect(harness.model.plan?.isEmpty == true)
    }

    @Test("A manual tempo overrides the detected one and rebuilds the grid")
    func manualTempoOverridesDetection() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "loop_100BPM.wav",
            contents: WAVFixture.tone(seconds: 4, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilInspected()
        #expect(harness.model.grid?.secondsPerBar == 2.4)
        harness.model.tempoBPM = 120
        #expect(harness.model.grid?.secondsPerBar == 2.0)
        #expect(harness.model.isTempoManual)
    }

    @Test("A manual tempo outside the range is clamped")
    func manualTempoIsClamped() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "loop.wav",
            contents: WAVFixture.tone(seconds: 2, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilInspected()
        harness.model.tempoBPM = 5_000
        #expect(harness.model.tempoBPM == Tempo.supportedRange.upperBound)
        harness.model.tempoBPM = 0
        #expect(harness.model.tempoBPM == Tempo.supportedRange.lowerBound)
    }

    @Test("Importing another sample drops the manual tempo")
    func newImportResetsManualTempo() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let first: URL = try harness.makeSourceFile(
            named: "first.wav",
            contents: WAVFixture.tone(seconds: 2, amplitude: 0.6)
        )
        let second: URL = try harness.makeSourceFile(
            named: "second_100BPM.wav",
            contents: WAVFixture.tone(seconds: 2, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(first))
        await harness.waitUntilInspected()
        harness.model.tempoBPM = 140
        #expect(harness.model.isTempoManual)
        harness.model.handlePickedFile(.success(second))
        await harness.waitUntilInspected()
        #expect(harness.model.isTempoManual == false)
        #expect(harness.model.tempoBPM == 100)
    }

    @Test("The grid offset moves slice starts and resets on import")
    func gridOffsetMovesStarts() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "loop_120BPM.wav",
            contents: WAVFixture.tone(seconds: 4, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilDecoded()
        let before: [TimeInterval] = harness.model.plan?.starts ?? []
        harness.model.gridOffset = 0.5
        let after: [TimeInterval] = harness.model.plan?.starts ?? []
        #expect(after.allSatisfy { $0 >= 0.5 })
        #expect(after != before)
        #expect(harness.model.effectiveGridOffset == 0.5)
    }

    @Test("An offset larger than the bar is clamped for the plan")
    func offsetIsClamped() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeSourceFile(
            named: "loop_120BPM.wav",
            contents: WAVFixture.tone(seconds: 4, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(source))
        await harness.waitUntilDecoded()
        harness.model.gridOffset = 10
        #expect(harness.model.effectiveGridOffset < 2)
    }

    @Test("The previous sample stays on screen while the next one is imported")
    func previousSampleSurvivesWhileImporting() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let first: URL = try harness.makeSourceFile(
            named: "first_120BPM.wav",
            contents: WAVFixture.tone(seconds: 2, amplitude: 0.6)
        )
        let second: URL = try harness.makeSourceFile(
            named: "second_100BPM.wav",
            contents: WAVFixture.tone(seconds: 2, amplitude: 0.6)
        )
        harness.model.handlePickedFile(.success(first))
        await harness.waitUntilDecoded()
        let previousInfo: SampleInfo = try #require(harness.model.info)
        harness.model.handlePickedFile(.success(second))
        #expect(harness.model.content == .importing)
        #expect(harness.model.info == previousInfo)
        #expect(harness.model.grid != nil)
        await harness.waitUntilDecoded()
    }

    @Test("Reshuffling changes the seed")
    func reshuffleChangesSeed() async {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let first: UInt64 = harness.model.seed
        harness.model.reshuffle()
        #expect(harness.model.seed != first)
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

    /// Decoding follows inspection, so the plan needs one more wait.
    func waitUntilDecoded() async {
        await waitUntilInspected()
        for _ in 0..<200 {
            if model.decoded != nil {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
