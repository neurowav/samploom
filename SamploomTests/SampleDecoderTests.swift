import Foundation
import Testing

@testable import Samploom

@Suite("SampleDecoder")
struct SampleDecoderTests {
    @Test("A WAV file decodes into samples and a waveform")
    func decodesWav() async throws {
        let url: URL = try WAVFixture.write(WAVFixture.tone(seconds: 0.5, amplitude: 0.5), named: "tone.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url, waveformBins: 64)
        #expect(abs(decoded.duration - 0.5) < 0.01)
        #expect(decoded.sampleRate == 44_100)
        #expect(decoded.samples.count > 20_000)
        #expect(decoded.waveform.count == 64)
        #expect(decoded.isSilent(startingAt: 0, length: 0.1) == false)
        #expect(decoded.isSilent(startingAt: 0.2, length: 0.1) == false)
    }

    @Test("Silence decodes to a silent sample")
    func decodesSilence() async throws {
        let url: URL = try WAVFixture.writeSilence(seconds: 0.2, named: "silence.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url)
        #expect(decoded.isSilent(startingAt: 0, length: 0.2))
    }
}
