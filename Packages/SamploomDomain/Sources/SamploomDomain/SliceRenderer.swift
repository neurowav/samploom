import Foundation

/// Cuts slice buffers out of decoded channels and fades their edges.
///
/// Straight cuts click: a slice rarely starts and ends on a zero crossing.
/// Short linear fades (5–20 ms) remove the click more reliably than searching
/// for zero crossings, and baking them here keeps playback trivial — the player
/// only has to schedule finished buffers.
///
/// A slice is always exactly as long as the plan says. If the tail runs past
/// the end of the sample it is zero-padded rather than shortened, so repeats
/// keep an even length and the player never has to guess.
public struct SliceRenderer: Sendable {
    public static let defaultFadeDuration: TimeInterval = 0.008

    public let fadeDuration: TimeInterval

    public init(fadeDuration: TimeInterval = defaultFadeDuration) {
        self.fadeDuration = max(0, fadeDuration)
    }

    public func render(plan: SlicePlan, channels: [[Float]], sampleRate: Double) -> [SliceAudio] {
        let frameCount: Int = channels.first?.count ?? 0
        guard sampleRate > 0, frameCount > 0, !channels.isEmpty else { return [] }
        let sliceFrames: Int = max(1, Int((plan.sliceLength * sampleRate).rounded()))
        let fadeFrames: Int = min(Int((fadeDuration * sampleRate).rounded()), sliceFrames / 2)
        return plan.starts.map { start in
            let startFrame: Int = max(0, Int((start * sampleRate).rounded()))
            let windows: [[Float]] = channels.map { channel in
                var window: [Float] = Array(repeating: 0, count: sliceFrames)
                let available: Int = min(sliceFrames, max(0, channel.count - startFrame))
                if available > 0 {
                    window.replaceSubrange(0..<available, with: channel[startFrame..<(startFrame + available)])
                }
                Self.applyFades(&window, fadeFrames: fadeFrames)
                return window
            }
            return .init(channels: windows, sampleRate: sampleRate, start: start)
        }
    }

    private static func applyFades(_ window: inout [Float], fadeFrames: Int) {
        guard fadeFrames > 0 else { return }
        let lastFrame: Int = window.count - 1
        for frame in 0..<fadeFrames {
            let gain: Float = Float(frame) / Float(fadeFrames)
            window[frame] *= gain
            window[lastFrame - frame] *= gain
        }
    }
}
