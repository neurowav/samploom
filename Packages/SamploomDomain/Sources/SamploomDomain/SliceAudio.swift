import Foundation

/// One slice of a sample, already cut and faded, ready for the player.
public struct SliceAudio: Sendable {
    /// One array per channel, faded, in -1...1.
    public let channels: [[Float]]
    public let sampleRate: Double
    /// Where the slice starts in the original sample.
    public let start: TimeInterval

    public init(channels: [[Float]], sampleRate: Double, start: TimeInterval) {
        self.channels = channels
        self.sampleRate = sampleRate
        self.start = start
    }

    public var frameCount: Int {
        channels.first?.count ?? 0
    }

    public var duration: TimeInterval {
        sampleRate > 0 ? Double(frameCount) / sampleRate : 0
    }
}
