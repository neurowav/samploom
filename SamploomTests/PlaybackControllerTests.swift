import Foundation
import SamploomDomain
import Testing

@testable import Samploom

@MainActor
@Suite("PlaybackController", .timeLimit(.minutes(1)))
struct PlaybackControllerTests {
    @Test("Play renders the whole plan and starts at the first slice")
    func playRendersThePlan() throws {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        let plan: SlicePlan = .init(sliceLength: 1, starts: [0, 1, 2, 3])
        controller.play(plan: plan, decoded: SampleFixture.decoded(duration: 4))
        #expect(controller.state == .playing)
        #expect(controller.currentSlice == 0)
        #expect(controller.sliceCount == 4)
        #expect(controller.progress == 0)
        let pass: [SliceAudio] = try #require(player.slices.last)
        #expect(pass.map(\.start) == plan.starts)
        #expect(pass.allSatisfy { $0.channels.count == 2 })
        #expect(pass.allSatisfy { $0.frameCount == 48_000 })
    }

    @Test("Slice boundaries move the position")
    func boundariesMovePosition() {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        controller.play(plan: .init(sliceLength: 1, starts: [0, 1, 2, 3]), decoded: SampleFixture.decoded())
        player.send(.finished(0))
        #expect(controller.currentSlice == 1)
        #expect(controller.progress == 0.25)
        player.send(.finished(1))
        #expect(controller.currentSlice == 2)
        player.send(.completed)
        #expect(controller.state == .finished)
        #expect(controller.progress == 1)
    }

    @Test("The highlight follows the planned starts")
    func highlightFollowsStarts() {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        controller.play(
            plan: .init(sliceLength: 1, starts: [0.5, 1.5, 2.5, 3.5]),
            decoded: SampleFixture.decoded()
        )
        #expect(controller.playingStart == 0.5)
        player.send(.finished(0))
        #expect(controller.playingStart == 1.5)
        controller.stop()
        #expect(controller.playingStart == nil)
    }

    @Test("Stop goes silent and ignores the rest of the pass")
    func stopIgnoresTheRestOfThePass() {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        controller.play(plan: .init(sliceLength: 1, starts: [0, 1, 2, 3]), decoded: SampleFixture.decoded())
        player.send(.finished(0))
        controller.stop()
        #expect(controller.state == .idle)
        #expect(controller.currentSlice == 0)
        #expect(controller.sliceCount == 0)
        #expect(controller.progress == 0)
        #expect(player.stopCount == 2)
        // The node reports slices it had buffered even after being stopped.
        player.send(.completed, pass: 0)
        #expect(controller.state == .idle)
        #expect(controller.currentSlice == 0)
    }

    @Test("An event from a previous pass cannot finish the new one")
    func staleEventsAreIgnored() {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        let plan: SlicePlan = .init(sliceLength: 1, starts: [0, 1, 2, 3])
        let decoded: DecodedSample = SampleFixture.decoded()
        controller.play(plan: plan, decoded: decoded)
        player.send(.finished(0), pass: 0)
        controller.play(plan: plan, decoded: decoded)
        #expect(controller.currentSlice == 0)
        player.send(.completed, pass: 0)
        #expect(controller.state == .playing)
        #expect(controller.currentSlice == 0)
        player.send(.finished(0), pass: 1)
        #expect(controller.currentSlice == 1)
    }

    @Test("Playing after a finished pass starts over")
    func replayStartsFromTheBeginning() {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        let plan: SlicePlan = .init(sliceLength: 1, starts: [0, 1, 2, 3])
        let decoded: DecodedSample = SampleFixture.decoded()
        controller.play(plan: plan, decoded: decoded)
        player.send(.completed)
        #expect(controller.state == .finished)
        controller.toggle(plan: plan, decoded: decoded)
        #expect(controller.state == .playing)
        #expect(controller.currentSlice == 0)
        #expect(player.slices.count == 2)
    }

    @Test("An empty plan never reaches the player")
    func emptyPlanDoesNotPlay() {
        let player: PlayerSpy = .init()
        let controller: PlaybackController = .init(player: player)
        controller.play(plan: .init(sliceLength: 1, starts: []), decoded: SampleFixture.decoded())
        #expect(controller.state == .idle)
        #expect(player.slices.isEmpty)
        #expect(player.stopCount == 0)
        controller.play(plan: .init(sliceLength: 1, starts: [0]), decoded: nil)
        #expect(controller.state == .idle)
        #expect(player.slices.isEmpty)
    }

    @Test("A failing player returns to idle and explains itself")
    func playerFailureIsReported() {
        let player: PlayerSpy = .init()
        player.failure = PlaybackError.unsupportedFormat
        let controller: PlaybackController = .init(player: player)
        controller.play(plan: .init(sliceLength: 1, starts: [0]), decoded: SampleFixture.decoded())
        #expect(controller.state == .idle)
        #expect(controller.sliceCount == 0)
        #expect(controller.failure == PlaybackError.unsupportedFormat.errorDescription)
    }
}
