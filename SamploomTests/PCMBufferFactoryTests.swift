import AVFoundation
import SamploomDomain
import Testing

@testable import Samploom

@Suite("PCMBufferFactory", .timeLimit(.minutes(1)))
struct PCMBufferFactoryTests {
    @Test("Stereo stays stereo")
    func stereoChannelsAreKept() throws {
        let slice: SliceAudio = .init(
            channels: [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]],
            sampleRate: 48_000,
            start: 0
        )
        let buffer: AVAudioPCMBuffer = try #require(PCMBufferFactory.makeBuffer(from: slice))
        #expect(buffer.format.channelCount == 2)
        #expect(buffer.format.sampleRate == 48_000)
        #expect(buffer.frameLength == 3)
        let channels: UnsafePointer<UnsafeMutablePointer<Float>> = try #require(buffer.floatChannelData)
        #expect(Array(UnsafeBufferPointer(start: channels[0], count: 3)) == [0.1, 0.2, 0.3])
        #expect(Array(UnsafeBufferPointer(start: channels[1], count: 3)) == [0.4, 0.5, 0.6])
    }

    @Test("Mono stays mono")
    func monoChannelIsKept() throws {
        let slice: SliceAudio = .init(channels: [[0.25, -0.25]], sampleRate: 44_100, start: 0)
        let buffer: AVAudioPCMBuffer = try #require(PCMBufferFactory.makeBuffer(from: slice))
        #expect(buffer.format.channelCount == 1)
        #expect(buffer.format.sampleRate == 44_100)
        #expect(buffer.frameLength == 2)
    }

    @Test("An empty or ragged slice produces no buffer")
    func invalidSlicesProduceNoBuffer() {
        #expect(PCMBufferFactory.makeBuffer(from: .init(channels: [], sampleRate: 48_000, start: 0)) == nil)
        #expect(PCMBufferFactory.makeBuffer(from: .init(channels: [[], []], sampleRate: 48_000, start: 0)) == nil)
        #expect(PCMBufferFactory.makeBuffer(from: .init(channels: [[0.1, 0.2], [0.1]], sampleRate: 48_000, start: 0)) == nil)
    }

    @Test("Fades baked by the renderer survive the conversion")
    func fadesSurviveTheConversion() throws {
        let channels: [[Float]] = [
            Array(repeating: 0.5, count: 4_800),
            Array(repeating: 0.5, count: 4_800)
        ]
        let renderer: SliceRenderer = .init()
        let slices: [SliceAudio] = renderer.render(
            plan: .init(sliceLength: 0.02, starts: [0]),
            channels: channels,
            sampleRate: 48_000
        )
        let slice: SliceAudio = try #require(slices.first)
        let buffer: AVAudioPCMBuffer = try #require(PCMBufferFactory.makeBuffer(from: slice))
        let data: UnsafePointer<UnsafeMutablePointer<Float>> = try #require(buffer.floatChannelData)
        #expect(buffer.frameLength == 960)
        #expect(data[0][0] == 0)
        #expect(data[0][959] == 0)
        #expect(abs(data[0][500] - 0.5) < 0.0001)
    }
}
