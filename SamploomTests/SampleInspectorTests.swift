import Foundation
import Testing

@testable import Samploom

@Suite("SampleInspector", .timeLimit(.minutes(1)))
struct SampleInspectorTests {
    @Test("Duration is read from a real WAV file")
    func readsDuration() async throws {
        let url: URL = try WAVFixture.writeSilence(seconds: 0.5, named: "fixture.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let inspector: SampleInspector = .init()
        let info: SampleInfo = try await inspector.inspect(fileAt: url, originalFileName: "fixture.wav")
        #expect(abs(info.duration - 0.5) < 0.01)
        #expect(info.tempo == nil)
    }

    @Test("Tempo falls back to the original file name")
    func tempoFromFileName() async throws {
        let url: URL = try WAVFixture.writeSilence(seconds: 0.1, named: "fixture.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let inspector: SampleInspector = .init()
        let info: SampleInfo = try await inspector.inspect(fileAt: url, originalFileName: "loop_140BPM.wav")
        #expect(info.tempo?.tempo.beatsPerMinute == 140)
        #expect(info.tempo?.source == .fileName)
    }
}
