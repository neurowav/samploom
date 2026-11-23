import Foundation
import Observation
import SamploomDomain

/// Drives one pass over the current slice plan.
///
/// The controller owns what the screen shows — idle, playing, finished. Events
/// carry the generation of the pass they belong to, because the audio node keeps
/// reporting buffered slices after Stop and those must not move the screen.
@Observable
@MainActor
final class PlaybackController {
    enum State: Equatable {
        case idle
        case playing
        case finished
    }

    private(set) var state: State = .idle
    /// Index of the slice being heard; zero while idle.
    private(set) var currentSlice: Int = 0
    private(set) var sliceCount: Int = 0
    /// Reason playback could not start, shown under the player.
    private(set) var failure: String?

    private let player: any SlicePlaying
    private let renderer: SliceRenderer
    private var starts: [TimeInterval] = []
    private var generation: Int = 0

    init(
        player: any SlicePlaying = AVAudioEnginePlayer(),
        renderer: SliceRenderer = .init()
    ) {
        self.player = player
        self.renderer = renderer
    }

    var isPlaying: Bool {
        state == .playing
    }

    /// 0...1 for the whole pass; a finished pass stays full.
    var progress: Double {
        guard sliceCount > 0 else { return 0 }
        switch state {
        case .idle:
            return 0
        case .playing:
            return min(1, Double(currentSlice) / Double(sliceCount))
        case .finished:
            return 1
        }
    }

    /// Start of the slice being heard, for the highlight on the waveform.
    var playingStart: TimeInterval? {
        guard state == .playing, starts.indices.contains(currentSlice) else { return nil }
        return starts[currentSlice]
    }

    func toggle(plan: SlicePlan?, decoded: DecodedSample?) async {
        if isPlaying {
            stop()
        } else {
            await play(plan: plan, decoded: decoded)
        }
    }

    func play(plan: SlicePlan?, decoded: DecodedSample?) async {
        guard let plan, let decoded, !plan.isEmpty else { return }
        let slices: [SliceAudio] = renderer.render(
            plan: plan,
            channels: decoded.channels,
            sampleRate: decoded.sampleRate
        )
        guard !slices.isEmpty else { return }
        stop()
        let token: Int = generation
        starts = plan.starts
        sliceCount = slices.count
        currentSlice = 0
        failure = nil
        state = .playing
        do {
            try await player.play(slices) { [weak self] event in
                self?.receive(event, token: token)
            }
            if token != generation {
                player.stop()
            }
        } catch {
            guard token == generation else { return }
            state = .idle
            currentSlice = 0
            sliceCount = 0
            starts = []
            failure = error.localizedDescription
        }
    }

    func stop() {
        // Invalidate first: the node may report a slice synchronously from stop().
        generation &+= 1
        state = .idle
        currentSlice = 0
        sliceCount = 0
        starts = []
        failure = nil
        player.stop()
    }

    private func receive(_ event: PlaybackEvent, token: Int) {
        guard token == generation, state == .playing else { return }
        switch event {
        case .finished(let index):
            currentSlice = min(index + 1, sliceCount - 1)
        case .completed:
            state = .finished
            currentSlice = max(0, sliceCount - 1)
        }
    }
}
