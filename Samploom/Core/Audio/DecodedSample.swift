import Foundation

/// Decoded audio plus what the screen needs: waveform peaks for drawing and
/// per-channel samples for loudness checks and, later, slicing.
///
/// Channels are kept as they were in the file: a mono mixdown would lose
/// stereo width, and summing channels for analysis would hide audible
/// out-of-phase material.
nonisolated struct DecodedSample: Sendable {
    /// About -60 dBFS: below this a slice counts as digital silence.
    static let silenceThreshold: Float = 0.001
    /// Engine and export rate. Files in other rates are converted once, on import.
    static let targetSampleRate: Double = 48_000
    /// Long files are cut on import: a few minutes of stereo samples would sit
    /// in memory as hundreds of megabytes, and loops are much shorter.
    static let maxDuration: TimeInterval = 40

    let sampleRate: Double
    /// One array per channel, float samples in -1...1.
    let channels: [[Float]]
    /// Peaks normalised to 0...1, one per waveform bin, taken across all channels.
    let waveform: [Float]
    /// True when the file was longer than `maxDuration` and only its head is kept.
    let isTruncated: Bool

    var frameCount: Int {
        channels.first?.count ?? 0
    }

    var duration: TimeInterval {
        sampleRate > 0 ? Double(frameCount) / sampleRate : 0
    }

    /// True when no channel has a sample above the silence threshold in the
    /// window, which is the case that must never become a slice. With `wraps`
    /// the window continues from the beginning of the sample.
    func isSilent(startingAt start: TimeInterval, length: TimeInterval, wraps: Bool = false) -> Bool {
        let lower: Int = max(0, Int((start * sampleRate).rounded(.down)))
        let upper: Int = Int(((start + length) * sampleRate).rounded(.up))
        guard lower < upper else { return true }
        if hasAudibleContent(from: lower, to: min(upper, frameCount)) {
            return false
        }
        guard wraps, upper > frameCount else { return true }
        return hasAudibleContent(from: 0, to: upper - frameCount) == false
    }

    private func hasAudibleContent(from lower: Int, to upper: Int) -> Bool {
        guard lower < upper else { return false }
        for channel in channels {
            for index in lower..<upper where abs(channel[index]) >= Self.silenceThreshold {
                return true
            }
        }
        return false
    }
}
