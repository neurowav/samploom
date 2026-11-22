import AVFoundation
import Foundation

/// Turns an imported file into samples the slicer can work with.
///
/// Decoding happens once per import; later stages reuse the array instead of
/// touching the file again. Real-time stretching and playback are separate
/// concerns and will read `samples` the same way.
actor SampleDecoder {
    enum Failure: LocalizedError {
        case unreadableFormat

        var errorDescription: String? {
            "This file cannot be decoded for slicing."
        }
    }

    func decode(fileAt url: URL, waveformBins: Int = 512) throws -> DecodedSample {
        let file: AVAudioFile = try .init(forReading: url)
        let format: AVAudioFormat = file.processingFormat
        let sampleRate: Double = format.sampleRate
        let channelCount: Int = Int(format.channelCount)
        guard sampleRate > 0, channelCount > 0, let buffer: AVAudioPCMBuffer = .init(
            pcmFormat: format,
            frameCapacity: 8192
        ) else {
            throw Failure.unreadableFormat
        }
        var samples: [Float] = []
        samples.reserveCapacity(Int(file.length))
        while file.framePosition < file.length {
            try file.read(into: buffer)
            let frames: Int = Int(buffer.frameLength)
            guard frames > 0, let channels: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else {
                break
            }
            for frame in 0..<frames {
                var sum: Float = 0
                for channel in 0..<channelCount {
                    sum += channels[channel][frame]
                }
                samples.append(sum / Float(channelCount))
            }
        }
        return .init(
            duration: Double(samples.count) / sampleRate,
            sampleRate: sampleRate,
            waveform: Self.waveform(from: samples, bins: waveformBins),
            samples: samples
        )
    }

    /// Reduces the sample to one peak per bin, normalised for drawing.
    private static func waveform(from samples: [Float], bins: Int) -> [Float] {
        guard !samples.isEmpty, bins > 0 else { return [] }
        let binSize: Int = max(1, Int((Double(samples.count) / Double(bins)).rounded(.up)))
        var peaks: [Float] = []
        var index: Int = 0
        while index < samples.count {
            let end: Int = min(index + binSize, samples.count)
            var peak: Float = 0
            for sampleIndex in index..<end {
                peak = max(peak, abs(samples[sampleIndex]))
            }
            peaks.append(peak)
            index = end
        }
        guard let maxPeak: Float = peaks.max(), maxPeak > 0 else { return peaks }
        return peaks.map { $0 / maxPeak }
    }
}
