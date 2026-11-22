import Foundation
import Testing

@testable import Samploom

@Suite("SampleDecoder")
struct SampleDecoderTests {
    @Test("A mono WAV decodes into one channel at the engine rate")
    func decodesMonoWav() async throws {
        let url: URL = try WAVFixture.write(WAVFixture.tone(seconds: 0.5, amplitude: 0.5), named: "tone.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url, waveformBins: 64)
        #expect(decoded.channels.count == 1)
        #expect(decoded.sampleRate == DecodedSample.targetSampleRate)
        #expect(abs(decoded.duration - 0.5) < 0.01)
        #expect(decoded.waveform.count == 64)
        #expect(decoded.isSilent(startingAt: 0, length: 0.1) == false)
        #expect(decoded.isSilent(startingAt: 0.2, length: 0.1) == false)
    }

    @Test("Stereo channels survive decoding with their own levels")
    func keepsStereoChannels() async throws {
        let data: Data = WAVFixture.tone(seconds: 0.5, amplitudes: [0.8, 0.2], sampleRate: 48_000)
        let url: URL = try WAVFixture.write(data, named: "stereo.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url)
        #expect(decoded.channels.count == 2)
        let left: Float = decoded.channels[0].map(abs).max() ?? 0
        let right: Float = decoded.channels[1].map(abs).max() ?? 0
        #expect(left > right * 2)
    }

    @Test("A 44.1 kHz file is converted to the engine rate")
    func convertsSampleRate() async throws {
        let url: URL = try WAVFixture.write(WAVFixture.tone(seconds: 0.25, sampleRate: 44_100), named: "rate.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url)
        #expect(decoded.sampleRate == 48_000)
        #expect(abs(decoded.duration - 0.25) < 0.01)
        #expect(decoded.frameCount == decoded.channels[0].count)
    }

    @Test("A file longer than the limit is truncated")
    func truncatesLongFiles() async throws {
        let url: URL = try WAVFixture.write(WAVFixture.tone(seconds: 2, sampleRate: 48_000), named: "long.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url, maxDuration: 1)
        #expect(abs(decoded.duration - 1) < 0.01)
        #expect(decoded.isTruncated)
    }

    @Test("A file within the limit is kept whole")
    func keepsShortFiles() async throws {
        let url: URL = try WAVFixture.write(WAVFixture.tone(seconds: 0.5, sampleRate: 48_000), named: "short.wav")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let decoder: SampleDecoder = .init()
        let decoded: DecodedSample = try await decoder.decode(fileAt: url)
        #expect(decoded.isTruncated == false)
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
