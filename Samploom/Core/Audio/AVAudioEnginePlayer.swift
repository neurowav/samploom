import AVFoundation
import Foundation
import SamploomDomain

/// Plays slices through one `AVAudioPlayerNode`.
///
/// Every buffer is scheduled before playback starts. Scheduling the next slice
/// from the previous one's completion handler would leave the node empty at each
/// join, which is audible on short slices.
@MainActor
final class AVAudioEnginePlayer: SlicePlaying {
    private let engine: AVAudioEngine = .init()
    private let node: AVAudioPlayerNode = .init()
    private var format: AVAudioFormat?

    init() {
        engine.attach(node)
    }

    func play(
        _ slices: [SliceAudio],
        onEvent: @escaping @MainActor (PlaybackEvent) -> Void
    ) throws {
        guard let first: SliceAudio = slices.first else {
            onEvent(.completed)
            return
        }
        guard let audioFormat: AVAudioFormat = .init(
            standardFormatWithSampleRate: first.sampleRate,
            channels: AVAudioChannelCount(first.channels.count)
        ) else { throw PlaybackError.unsupportedFormat }
        let buffers: [AVAudioPCMBuffer] = try slices.map { slice in
            guard let buffer: AVAudioPCMBuffer = PCMBufferFactory.makeBuffer(from: slice) else {
                throw PlaybackError.bufferAllocationFailed
            }
            return buffer
        }
        try activateSession()
        try prepare(format: audioFormat)
        node.stop()
        node.reset()
        let lastIndex: Int = buffers.count - 1
        for (index, buffer) in buffers.enumerated() {
            node.scheduleBuffer(
                buffer,
                at: nil,
                options: [],
                completionCallbackType: .dataPlayedBack
            ) { _ in
                // The node calls back off the main thread; the UI state is main-actor bound.
                Task { @MainActor in
                    onEvent(index == lastIndex ? .completed : .finished(index))
                }
            }
        }
        node.play()
    }

    func stop() {
        node.stop()
        node.reset()
    }

    /// `.playback`, not the default ambient category: a sampler should be heard
    /// even when the ring/silent switch is on.
    private func activateSession() throws {
        let session: AVAudioSession = .sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func prepare(format newFormat: AVAudioFormat) throws {
        if engine.isRunning, format == newFormat { return }
        node.stop()
        engine.stop()
        engine.disconnectNodeOutput(node)
        engine.connect(node, to: engine.mainMixerNode, format: newFormat)
        engine.prepare()
        try engine.start()
        format = newFormat
    }
}
