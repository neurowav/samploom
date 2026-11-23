import Foundation
import SamploomDomain

/// What a player reports while a pass runs.
///
/// `finished(_:)` carries the index of the slice that just ended, so the screen
/// can move the highlight to the next one. `completed` closes the pass.
nonisolated enum PlaybackEvent: Equatable, Sendable {
    case finished(Int)
    case completed
}

/// Plays baked slices once, in order. Behind a protocol so tests can deliver the
/// events themselves instead of waiting for real audio.
@MainActor
protocol SlicePlaying: AnyObject {
    /// Schedules the whole pass before the first sample is heard: scheduling the
    /// next slice from a completion handler leaves an audible gap at the join.
    func play(
        _ slices: [SliceAudio],
        onEvent: @escaping @MainActor (PlaybackEvent) -> Void
    ) throws
    /// Drops everything that is still scheduled and goes silent.
    func stop()
}
