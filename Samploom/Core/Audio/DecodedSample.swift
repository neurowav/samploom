import Foundation

/// Decoded audio plus what the screen needs: waveform peaks for drawing and a
/// mono mixdown for checking whether a slice carries any audible content.
nonisolated struct DecodedSample: Sendable {
    /// About -60 dBFS: below this a slice counts as digital silence.
    static let silenceThreshold: Float = 0.001

    let duration: TimeInterval
    let sampleRate: Double
    /// Peaks normalised to 0...1, one per waveform bin.
    let waveform: [Float]
    /// Mono mixdown in -1...1.
    let samples: [Float]

    /// True when the window has no sample above the silence threshold, which
    /// is the case that must never become a slice.
    func isSilent(startingAt start: TimeInterval, length: TimeInterval) -> Bool {
        let lower: Int = max(0, Int((start * sampleRate).rounded(.down)))
        let upper: Int = min(samples.count, Int(((start + length) * sampleRate).rounded(.up)))
        guard lower < upper else { return true }
        var peak: Float = 0
        for index in lower..<upper {
            peak = max(peak, abs(samples[index]))
        }
        return peak < Self.silenceThreshold
    }
}
