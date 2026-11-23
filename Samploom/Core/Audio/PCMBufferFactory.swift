import AVFoundation
import SamploomDomain

/// Turns a baked slice into a player buffer.
///
/// The buffer's format comes from the slice itself: the sample rate is
/// normalised on import, but the channel count still follows the file, so a mono
/// sample stays mono and a stereo one keeps both channels.
nonisolated enum PCMBufferFactory {
    static func makeBuffer(from slice: SliceAudio) -> AVAudioPCMBuffer? {
        makeBuffer(channels: slice.channels, sampleRate: slice.sampleRate)
    }

    static func makeBuffer(channels: [[Float]], sampleRate: Double) -> AVAudioPCMBuffer? {
        let frameCount: Int = channels.first?.count ?? 0
        guard frameCount > 0,
              channels.allSatisfy({ $0.count == frameCount }),
              let channelCount: AVAudioChannelCount = .init(exactly: channels.count),
              let capacity: AVAudioFrameCount = .init(exactly: frameCount),
              let format: AVAudioFormat = .init(
                  standardFormatWithSampleRate: sampleRate,
                  channels: channelCount
              ),
              let buffer: AVAudioPCMBuffer = .init(pcmFormat: format, frameCapacity: capacity),
              let data: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData
        else { return nil }
        buffer.frameLength = capacity
        for (index, channel) in channels.enumerated() {
            data[index].update(from: channel, count: frameCount)
        }
        return buffer
    }
}
