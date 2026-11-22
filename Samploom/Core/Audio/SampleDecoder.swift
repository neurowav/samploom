import AVFoundation
import Foundation

/// Turns an imported file into samples the slicer can work with.
///
/// Decoding happens once per import: channels are preserved, the rate is
/// normalised to the engine rate, and later stages reuse the arrays instead of
/// touching the file again.
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
        guard file.length > 0, format.channelCount > 0, let input: AVAudioPCMBuffer = .init(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw Failure.unreadableFormat
        }
        try file.read(into: input)
        let channels: [[Float]]
        if format.sampleRate == DecodedSample.targetSampleRate {
            channels = try Self.channels(of: input)
        } else {
            channels = try Self.resampled(input, toRate: DecodedSample.targetSampleRate)
        }
        return .init(
            sampleRate: DecodedSample.targetSampleRate,
            channels: channels,
            waveform: Self.waveform(from: channels, bins: waveformBins)
        )
    }

    private static func channels(of buffer: AVAudioPCMBuffer) throws -> [[Float]] {
        guard let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else {
            throw Failure.unreadableFormat
        }
        let frames: Int = Int(buffer.frameLength)
        let channelCount: Int = Int(buffer.format.channelCount)
        return (0..<channelCount).map { index in
            Array(UnsafeBufferPointer(start: channelData[index], count: frames))
        }
    }

    /// Converts to the target rate in chunks so a long file does not need a
    /// second full-size buffer.
    private static func resampled(_ input: AVAudioPCMBuffer, toRate rate: Double) throws -> [[Float]] {
        guard let format: AVAudioFormat = .init(
            commonFormat: .pcmFormatFloat32,
            sampleRate: rate,
            channels: input.format.channelCount,
            interleaved: false
        ), let converter: AVAudioConverter = .init(from: input.format, to: format) else {
            throw Failure.unreadableFormat
        }
        let channelCount: Int = Int(format.channelCount)
        var channels: [[Float]] = Array(repeating: [], count: channelCount)
        var didProvideInput: Bool = false
        var status: AVAudioConverterOutputStatus = .haveData
        while status == .haveData {
            guard let chunk: AVAudioPCMBuffer = .init(pcmFormat: format, frameCapacity: 16_384) else {
                throw Failure.unreadableFormat
            }
            var conversionError: NSError?
            status = converter.convert(to: chunk, error: &conversionError) { _, inputStatus in
                if didProvideInput {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                didProvideInput = true
                inputStatus.pointee = .haveData
                return input
            }
            guard conversionError == nil, let channelData = chunk.floatChannelData else {
                throw Failure.unreadableFormat
            }
            let frames: Int = Int(chunk.frameLength)
            for index in 0..<channelCount {
                channels[index].append(contentsOf: UnsafeBufferPointer(start: channelData[index], count: frames))
            }
        }
        guard channels.first?.isEmpty == false else { throw Failure.unreadableFormat }
        return channels
    }

    /// Reduces the sample to one peak per bin, normalised for drawing.
    private static func waveform(from channels: [[Float]], bins: Int) -> [Float] {
        let frameCount: Int = channels.first?.count ?? 0
        guard frameCount > 0, bins > 0 else { return [] }
        let binSize: Int = max(1, Int((Double(frameCount) / Double(bins)).rounded(.up)))
        var peaks: [Float] = []
        var index: Int = 0
        while index < frameCount {
            let end: Int = min(index + binSize, frameCount)
            var peak: Float = 0
            for channel in channels {
                for sampleIndex in index..<end {
                    peak = max(peak, abs(channel[sampleIndex]))
                }
            }
            peaks.append(peak)
            index = end
        }
        guard let maxPeak: Float = peaks.max(), maxPeak > 0 else { return peaks }
        return peaks.map { $0 / maxPeak }
    }
}
