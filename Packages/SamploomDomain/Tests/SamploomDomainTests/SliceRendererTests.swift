import Foundation
import Testing

@testable import SamploomDomain

@Suite("SliceRenderer")
struct SliceRendererTests {
    private let sampleRate: Double = 1_000
    private let renderer: SliceRenderer = .init(fadeDuration: 0.005)

    @Test("One buffer per repeat, all the same length")
    func rendersOneBufferPerRepeat() {
        let plan: SlicePlan = .init(sliceLength: 0.1, starts: [0, 0.2, 0.4, 0.6])
        let slices: [SliceAudio] = renderer.render(plan: plan, channels: [ramp(frames: 1_000)], sampleRate: sampleRate)
        #expect(slices.count == 4)
        #expect(slices.allSatisfy { $0.frameCount == 100 })
        #expect(slices.map(\.start) == [0, 0.2, 0.4, 0.6])
    }

    @Test("A slice carries the audio from its start position")
    func sliceContent() {
        let channel: [Float] = (0..<1_000).map { Float($0) / 1_000 }
        let plan: SlicePlan = .init(sliceLength: 0.1, starts: [0.1])
        let slices: [SliceAudio] = renderer.render(plan: plan, channels: [channel], sampleRate: sampleRate)
        let slice: SliceAudio = slices[0]
        // Middle of the slice is untouched by the fades.
        #expect(abs(slice.channels[0][50] - channel[150]) < 0.000_001)
    }

    @Test("Both edges are faded to zero")
    func edgesAreFaded() {
        let plan: SlicePlan = .init(sliceLength: 0.1, starts: [0])
        let channel: [Float] = Array(repeating: 1, count: 1_000)
        let slices: [SliceAudio] = renderer.render(plan: plan, channels: [channel], sampleRate: sampleRate)
        let slice: SliceAudio = slices[0]
        #expect(slice.channels[0].first == 0)
        #expect(slice.channels[0].last == 0)
        #expect(slice.channels[0][50] == 1)
        #expect(slice.channels[0][4] < slice.channels[0][5])
    }

    @Test("A window past the end is zero-padded when wrapping is off")
    func padsPastTheEnd() {
        let channel: [Float] = Array(repeating: 0.5, count: 500)
        let plan: SlicePlan = .init(sliceLength: 1, starts: [0])
        let slices: [SliceAudio] = renderer.render(
            plan: plan,
            channels: [channel],
            sampleRate: sampleRate,
            wraps: false
        )
        let slice: SliceAudio = slices[0]
        #expect(slice.frameCount == 1_000)
        #expect(slice.channels[0][700] == 0)
    }

    @Test("A window past the end continues from the beginning when wrapping is on")
    func wrapsPastTheEnd() {
        let channel: [Float] = (0..<500).map { _ in 0.5 }
        let plan: SlicePlan = .init(sliceLength: 1, starts: [0.2])
        let slices: [SliceAudio] = renderer.render(plan: plan, channels: [channel], sampleRate: sampleRate)
        let slice: SliceAudio = slices[0]
        #expect(slice.frameCount == 1_000)
        // 0.2 s in: 300 frames are left, the next 500 come from the beginning,
        // and the rest of the window stays silent because one pass is not enough.
        #expect(slice.channels[0][350] == 0.5)
        #expect(slice.channels[0][900] == 0)
    }

    @Test("Fades are capped at half the slice")
    func fadeCappedOnShortSlices() {
        let channel: [Float] = Array(repeating: 1, count: 1_000)
        let plan: SlicePlan = .init(sliceLength: 0.004, starts: [0])
        let slices: [SliceAudio] = renderer.render(plan: plan, channels: [channel], sampleRate: sampleRate)
        let slice: SliceAudio = slices[0]
        #expect(slice.frameCount == 4)
        #expect(slice.channels[0].first == 0)
        #expect(slice.channels[0].last == 0)
    }

    @Test("Every channel gets the same treatment")
    func stereoChannels() {
        let left: [Float] = Array(repeating: 0.8, count: 1_000)
        let right: [Float] = Array(repeating: -0.4, count: 1_000)
        let plan: SlicePlan = .init(sliceLength: 0.1, starts: [0])
        let slices: [SliceAudio] = renderer.render(plan: plan, channels: [left, right], sampleRate: sampleRate)
        #expect(slices[0].channels.count == 2)
        #expect(slices[0].channels[0][50] == 0.8)
        #expect(slices[0].channels[1][50] == -0.4)
    }

    @Test("Empty input gives no slices")
    func emptyInput() {
        let plan: SlicePlan = .init(sliceLength: 0.1, starts: [0])
        #expect(renderer.render(plan: plan, channels: [], sampleRate: sampleRate).isEmpty)
        #expect(renderer.render(plan: plan, channels: [[]], sampleRate: sampleRate).isEmpty)
    }

    private func ramp(frames: Int) -> [Float] {
        (0..<frames).map { Float($0) / Float(frames) }
    }
}
