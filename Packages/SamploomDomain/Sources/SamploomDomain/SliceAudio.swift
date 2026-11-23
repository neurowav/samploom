import Foundation

/// One slice of a sample, already cut and faded, ready for the player.
public struct SliceAudio: Sendable {
    /// One array per channel, faded, in -1...1.
    public let channels: [[Float]]
    public let sampleRate: Double
    /// Where the slice starts in the original sample.
    public let start: TimeInterval
    /// Fade baked into both edges. A player that overlaps neighbours by this
    /// much turns the two fade-outs into a crossfade instead of a dip.
    public let fadeDuration: TimeInterval

    public init(
        channels: [[Float]],
        sampleRate: Double,
        start: TimeInterval,
        fadeDuration: TimeInterval = 0
    ) {
        self.channels = channels
        self.sampleRate = sampleRate
        self.start = start
        self.fadeDuration = max(0, fadeDuration)
    }

    public var frameCount: Int {
        channels.first?.count ?? 0
    }

    public var duration: TimeInterval {
        sampleRate > 0 ? Double(frameCount) / sampleRate : 0
    }
}
