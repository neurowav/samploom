import Foundation
import SamploomDomain

/// One continuous playable pass assembled from slices.
nonisolated struct SlicePass: Sendable {
    let sampleRate: Double
    /// Contiguous spans of the pass, one per slice. Playing them in order gives
    /// exactly the same signal as the whole pass: the cuts are sample boundaries.
    let segments: [[[Float]]]
}

/// Joins slices into one gapless pass.
///
/// The fades baked into the slices are not wasted: each slice's fade-out is
/// overlapped by the next slice's fade-in, so the join is a crossfade. In the
/// middle of the overlap the two gains add up to roughly one, and the signal
/// never drops to silence — which is what a plain fade-out followed by a
/// fade-in sounds like between slices.
nonisolated enum SlicePassBuilder {
    static func build(from slices: [SliceAudio]) -> SlicePass? {
        guard let first: SliceAudio = slices.first,
              let frameCount: Int = first.channels.first?.count,
              frameCount > 0,
              first.channels.isEmpty == false,
              first.sampleRate > 0
        else { return nil }
        let channelCount: Int = first.channels.count
        let isCompatible: Bool = slices.allSatisfy { slice in
            slice.sampleRate == first.sampleRate
                && slice.fadeDuration == first.fadeDuration
                && slice.channels.count == channelCount
                && slice.channels.allSatisfy { $0.count == frameCount }
        }
        guard isCompatible else { return nil }
        let fadeFrames: Int = min(
            Int((first.fadeDuration * first.sampleRate).rounded()),
            frameCount / 2
        )
        let step: Int = max(1, frameCount - fadeFrames)
        let totalFrames: Int = step * (slices.count - 1) + frameCount
        var mix: [[Float]] = Array(
            repeating: Array(repeating: 0, count: totalFrames),
            count: channelCount
        )
        for (index, slice) in slices.enumerated() {
            let offset: Int = index * step
            for channel in 0..<channelCount {
                for frame in 0..<frameCount {
                    mix[channel][offset + frame] += slice.channels[channel][frame]
                }
            }
        }
        let segments: [[[Float]]] = slices.indices.map { index in
            let lower: Int = index * step
            let upper: Int = index == slices.count - 1 ? totalFrames : lower + step
            return mix.map { Array($0[lower..<upper]) }
        }
        return .init(sampleRate: first.sampleRate, segments: segments)
    }
}
