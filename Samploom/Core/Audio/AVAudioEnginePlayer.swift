import AVFoundation
import Foundation
import SamploomDomain

/// Plays slices through one `AVAudioPlayerNode`.
///
/// Slices are first joined into a gapless pass: each baked fade-out is covered
/// by the next fade-in, so a repeat does not dip to silence at the join. The
/// pass is then cut into contiguous segments, one per slice, and all of them are
/// scheduled before playback starts — scheduling the next segment from a
/// completion handler would leave the node empty at each cut.
@MainActor
final class AVAudioEnginePlayer: SlicePlaying {
    private let engine: AVAudioEngine = .init()
    private let node: AVAudioPlayerNode = .init()
    private var format: AVAudioFormat?
    private var isSessionConfigured: Bool = false
    /// Bumped by `stop()`: a pass that is still waiting for the session must not
    /// start scheduling after the user has stopped it.
    private var playGeneration: Int = 0

    init() {
        engine.attach(node)
    }

    func play(
        _ slices: [SliceAudio],
        onEvent: @escaping @MainActor (PlaybackEvent) -> Void
    ) async throws {
        guard let first: SliceAudio = slices.first else {
            onEvent(.completed)
            return
        }
        guard let pass: SlicePass = SlicePassBuilder.build(from: slices) else {
            throw PlaybackError.inconsistentSlices
        }
        guard let audioFormat: AVAudioFormat = .init(
            standardFormatWithSampleRate: pass.sampleRate,
            channels: AVAudioChannelCount(first.channels.count)
        ) else { throw PlaybackError.unsupportedFormat }
        let buffers: [AVAudioPCMBuffer] = try pass.segments.map { segment in
            guard let buffer: AVAudioPCMBuffer = PCMBufferFactory.makeBuffer(
                channels: segment,
                sampleRate: pass.sampleRate
            ) else { throw PlaybackError.bufferAllocationFailed }
            return buffer
        }
        playGeneration &+= 1
        let generation: Int = playGeneration
        try await activateSession()
        guard generation == playGeneration else { return }
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
        playGeneration &+= 1
        node.stop()
        node.reset()
    }

    /// `.playback`, not the default ambient category: a sampler should be heard
    /// even when the ring/silent switch is on. The session is configured once and
    /// activated without blocking the main thread.
    private func activateSession() async throws {
        let session: AVAudioSession = .sharedInstance()
        if isSessionConfigured == false {
            try session.setCategory(.playback, mode: .default)
            isSessionConfigured = true
        }
        if #available(iOS 27.0, *) {
            try await activate(session)
        } else {
            try await Task.detached(priority: .userInitiated) {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
        }
    }

    @available(iOS 27.0, *)
    private func activate(_ session: AVAudioSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            session.activate(options: []) { activated, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if activated {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PlaybackError.sessionActivationFailed)
                }
            }
        }
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
