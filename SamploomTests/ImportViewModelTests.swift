import Foundation
import SamploomDomain
import Testing

@testable import Samploom

@MainActor
@Suite("ImportViewModel", .timeLimit(.minutes(1)))
struct ImportViewModelTests {
    @Test("Importing a file ends in the imported state")
    func importSetsImportedContent() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "break 174BPM.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        let sample: ImportedSample = try #require(harness.model.currentSample)
        #expect(sample.displayName == "break 174BPM.wav")
        #expect(harness.model.errorMessage == nil)
    }

    @Test("Replacing a sample removes the previous copy")
    func replaceRemovesPreviousCopy() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let first: URL = try harness.makeFile(named: "first.wav", data: Data("RIFF".utf8))
        let second: URL = try harness.makeFile(named: "second.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: first)
        let firstSample: ImportedSample = try #require(harness.model.currentSample)
        await harness.model.importSample(from: second)
        #expect(FileManager.default.fileExists(atPath: firstSample.url.path(percentEncoded: false)) == false)
    }

    @Test("A failed import reports the error and keeps the previous sample")
    func failureKeepsPreviousState() async throws {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "loop.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        let previous: ImportedSample = try #require(harness.model.currentSample)
        let missing: URL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        await harness.model.importSample(from: missing)
        #expect(harness.model.currentSample == previous)
        #expect(harness.model.errorMessage != nil)
    }

    @Test("A cancelled picker does not change the state")
    func cancellationIsSilent() {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        harness.model.handlePickedFile(.failure(CocoaError(.userCancelled)))
        #expect(harness.model.currentSample == nil)
        #expect(harness.model.errorMessage == nil)
    }

    @Test("The grid follows the detected tempo")
    func gridFromDetectedTempo() async throws {
        let harness: Harness = .init(info: SampleFixture.info(tempo: try .init(beatsPerMinute: 128)))
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "loop.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        #expect(harness.model.grid?.secondsPerBar == 1.875)
        #expect(harness.model.info?.tempo?.source == .fileName)
    }

    @Test("A manual tempo overrides the detected one and is clamped")
    func manualTempoOverridesAndClamps() async throws {
        let harness: Harness = .init(info: SampleFixture.info(tempo: try .init(beatsPerMinute: 100)))
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "loop.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        harness.model.tempoBPM = 120
        #expect(harness.model.grid?.secondsPerBar == 2.0)
        #expect(harness.model.isTempoManual)
        harness.model.tempoBPM = 5_000
        #expect(harness.model.tempoBPM == Tempo.supportedRange.upperBound)
        harness.model.tempoBPM = 0
        #expect(harness.model.tempoBPM == Tempo.supportedRange.lowerBound)
    }

    @Test("Importing another sample drops the manual tempo")
    func newImportResetsManualTempo() async throws {
        let harness: Harness = .init(info: SampleFixture.info(tempo: try .init(beatsPerMinute: 100)))
        defer { harness.cleanUp() }
        let first: URL = try harness.makeFile(named: "first.wav", data: Data("RIFF".utf8))
        let second: URL = try harness.makeFile(named: "second.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: first)
        harness.model.tempoBPM = 140
        #expect(harness.model.isTempoManual)
        await harness.model.importSample(from: second)
        #expect(harness.model.isTempoManual == false)
        #expect(harness.model.tempoBPM == 100)
    }

    @Test("The plan is built from the decoded audio")
    func planFromDecodedAudio() async throws {
        let harness: Harness = .init(
            info: SampleFixture.info(tempo: try .init(beatsPerMinute: 120)),
            decoded: SampleFixture.decoded(duration: 4)
        )
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "loop.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        let plan: SlicePlan = try #require(harness.model.plan)
        #expect(plan.sliceLength == 2.0)
        #expect(plan.starts.count == 4)
    }

    @Test("A finer division makes the slice shorter")
    func finerDivisionShortensSlice() async throws {
        let harness: Harness = .init(
            info: SampleFixture.info(tempo: try .init(beatsPerMinute: 120)),
            decoded: SampleFixture.decoded(duration: 4)
        )
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "loop.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        #expect(harness.model.plan?.sliceLength == 2.0)
        harness.model.division = .halfBeat
        #expect(harness.model.plan?.sliceLength == 0.25)
        harness.model.division = .quarterBeat
        #expect(harness.model.plan?.sliceLength == 0.125)
    }

    @Test("A silent sample gives an empty plan instead of empty slices")
    func silentSampleHasNoPlan() async throws {
        let harness: Harness = .init(
            info: SampleFixture.info(tempo: try .init(beatsPerMinute: 120)),
            decoded: SampleFixture.silent(duration: 4)
        )
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "silence.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        #expect(harness.model.plan?.isEmpty == true)
    }

    @Test("The grid offset moves slice starts and is clamped")
    func gridOffsetMovesStarts() async throws {
        let harness: Harness = .init(
            info: SampleFixture.info(tempo: try .init(beatsPerMinute: 120)),
            decoded: SampleFixture.decoded(duration: 4)
        )
        defer { harness.cleanUp() }
        let source: URL = try harness.makeFile(named: "loop.wav", data: Data("RIFF".utf8))
        await harness.model.importSample(from: source)
        let before: [TimeInterval] = harness.model.plan?.starts ?? []
        harness.model.gridOffset = 0.5
        let after: [TimeInterval] = harness.model.plan?.starts ?? []
        #expect(after.allSatisfy { $0 >= 0.5 })
        #expect(after != before)
        harness.model.gridOffset = 10
        #expect(harness.model.effectiveGridOffset < 2)
    }

    @Test("The previous sample stays visible until the new one is analysed")
    func previousSampleStaysWhileImporting() async throws {
        let root: URL = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let decoder: DecoderSpy = .init()
        let model: ImportViewModel = .init(
            storage: Self.makeStorage(root: root),
            inspector: InspectorSpy(info: SampleFixture.info()),
            decoder: decoder
        )
        let first: URL = try Self.makeFile(root: root, named: "first.wav", data: Data("RIFF".utf8))
        let second: URL = try Self.makeFile(root: root, named: "second.wav", data: Data("RIFF".utf8))
        await decoder.prepare(.success(SampleFixture.decoded(duration: 2)))
        await model.importSample(from: first)
        let previous: ImportedSample = try #require(model.currentSample)
        // The second decode waits for the test, so the moment in between can be inspected.
        let importing: Task<Void, Never> = Task { await model.importSample(from: second) }
        await decoder.waitUntilDecodeStarts()
        #expect(model.content == .importing)
        #expect(model.currentSample == previous)
        await decoder.prepare(.success(SampleFixture.decoded(duration: 3)))
        await importing.value
        #expect(model.currentSample?.displayName == "second.wav")
        #expect(model.content != .importing)
    }

    @Test("A newer pick cancels the import that is still running")
    func newPickCancelsPreviousImport() async throws {
        let root: URL = Self.makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let decoder: DecoderSpy = .init()
        let model: ImportViewModel = .init(
            storage: Self.makeStorage(root: root),
            inspector: InspectorSpy(info: SampleFixture.info()),
            decoder: decoder
        )
        let first: URL = try Self.makeFile(root: root, named: "first.wav", data: Data("RIFF".utf8))
        let second: URL = try Self.makeFile(root: root, named: "second.wav", data: Data("RIFF".utf8))
        model.handlePickedFile(.success(first))
        await decoder.waitUntilDecodeStarts()
        await decoder.prepare(.success(SampleFixture.decoded(duration: 2)))
        model.handlePickedFile(.success(second))
        await decoder.waitUntilDecodeStarts()
        await decoder.prepare(.success(SampleFixture.decoded(duration: 3)))
        await model.awaitPendingImport()
        #expect(model.currentSample?.displayName == "second.wav")
        #expect(model.errorMessage == nil)
    }

    @Test("Reshuffling changes the seed")
    func reshuffleChangesSeed() {
        let harness: Harness = .init()
        defer { harness.cleanUp() }
        let first: UInt64 = harness.model.seed
        harness.model.reshuffle()
        #expect(harness.model.seed != first)
    }

    static func makeRoot() -> URL {
        URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    static func makeStorage(root: URL) -> SampleStorage {
        .init(directory: root.appending(path: "Imported", directoryHint: .isDirectory))
    }

    static func makeFile(root: URL, named name: String, data: Data) throws -> URL {
        let directory: URL = root.appending(path: "Source", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url: URL = directory.appending(path: name)
        try data.write(to: url)
        return url
    }
}

/// Model wired with stubs by default: no AVFoundation, no waiting for real audio.
private struct Harness {
    let model: ImportViewModel
    let root: URL

    init(info: SampleInfo? = nil, decoded: DecodedSample? = SampleFixture.decoded()) {
        let root: URL = ImportViewModelTests.makeRoot()
        self.root = root
        self.model = .init(
            storage: ImportViewModelTests.makeStorage(root: root),
            inspector: InspectorSpy(info: info),
            decoder: StubDecoder(decoded: decoded)
        )
    }

    func makeFile(named name: String, data: Data) throws -> URL {
        try ImportViewModelTests.makeFile(root: root, named: name, data: data)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
