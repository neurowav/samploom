import Foundation
import SamploomDomain
import Testing

@testable import Samploom

@Suite("SlicePassBuilder", .timeLimit(.minutes(1)))
struct SlicePassBuilderTests {
    private let sampleRate: Double = 1_000
    private let renderer: SliceRenderer = .init(fadeDuration: 0.005)

    @Test("Slices are joined without a dip to silence")
    func joinsAreCrossfaded() throws {
        let slices: [SliceAudio] = renderer.render(
            plan: .init(sliceLength: 0.1, starts: [0, 0, 0, 0]),
            channels: [Array(repeating: 0.5, count: 2_000)],
            sampleRate: sampleRate
        )
        let pass: SlicePass = try #require(SlicePassBuilder.build(from: slices))
        #expect(pass.segments.count == 4)
        let joined: [Float] = pass.segments.flatMap { $0[0] }
        // Four 100-frame slices overlap by one 5-frame fade at each of three joins.
        #expect(joined.count == 385)
        // A fade-out followed by a fade-in would reach zero here; a crossfade stays audible.
        // The first and last fade frames belong to the pass edges, not to a join.
        #expect(joined.dropFirst(5).dropLast(5).allSatisfy { $0 >= 0.39 })
        #expect(joined.first == 0)
        #expect(joined.last == 0)
    }

    @Test("The last segment keeps the full slice length")
    func segmentLengths() throws {
        let slices: [SliceAudio] = renderer.render(
            plan: .init(sliceLength: 0.1, starts: [0, 0, 0, 0]),
            channels: [Array(repeating: 0.5, count: 2_000)],
            sampleRate: sampleRate
        )
        let pass: SlicePass = try #require(SlicePassBuilder.build(from: slices))
        #expect(pass.segments[0][0].count == 95)
        #expect(pass.segments[3][0].count == 100)
    }

    @Test("Channels stay separate")
    func stereoChannels() throws {
        let left: [Float] = Array(repeating: 0.5, count: 2_000)
        let right: [Float] = Array(repeating: -0.25, count: 2_000)
        let slices: [SliceAudio] = renderer.render(
            plan: .init(sliceLength: 0.1, starts: [0, 0]),
            channels: [left, right],
            sampleRate: sampleRate
        )
        let pass: SlicePass = try #require(SlicePassBuilder.build(from: slices))
        #expect(pass.segments.allSatisfy { $0.count == 2 })
        #expect(pass.segments[0][0][50] == 0.5)
        #expect(pass.segments[0][1][50] == -0.25)
    }

    @Test("An eight millisecond crossfade stays at full level")
    func realisticCrossfade() throws {
        let slices: [SliceAudio] = SliceRenderer().render(
            plan: .init(sliceLength: 0.5, starts: [0, 0, 0, 0]),
            channels: [Array(repeating: 0.5, count: 24_000)],
            sampleRate: 48_000
        )
        let pass: SlicePass = try #require(SlicePassBuilder.build(from: slices))
        let joined: [Float] = pass.segments.flatMap { $0[0] }
        let body: [Float] = Array(joined.dropFirst(384).dropLast(384))
        let minimum: Float = try #require(body.min())
        #expect(minimum >= 0.498)
    }

    @Test("Without fades the slices are simply concatenated")
    func noFadeMeansConcatenation() throws {
        let slices: [SliceAudio] = [
            .init(channels: [[1, 2]], sampleRate: sampleRate, start: 0),
            .init(channels: [[3, 4]], sampleRate: sampleRate, start: 0)
        ]
        let pass: SlicePass = try #require(SlicePassBuilder.build(from: slices))
        #expect(pass.segments.count == 2)
        #expect(pass.segments.flatMap { $0[0] } == [1, 2, 3, 4])
    }

    @Test("Slices with different shapes are rejected")
    func incompatibleSlices() {
        let short: SliceAudio = .init(channels: [[1, 2]], sampleRate: sampleRate, start: 0)
        let long: SliceAudio = .init(channels: [[1, 2, 3]], sampleRate: sampleRate, start: 0)
        #expect(SlicePassBuilder.build(from: [short, long]) == nil)
        let otherRate: SliceAudio = .init(channels: [[1, 2]], sampleRate: 2_000, start: 0)
        #expect(SlicePassBuilder.build(from: [short, otherRate]) == nil)
        #expect(SlicePassBuilder.build(from: []) == nil)
    }
}
