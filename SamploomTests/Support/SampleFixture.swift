import Foundation
import SamploomDomain

@testable import Samploom

/// Ready-made values so tests do not decode real audio unless they are about decoding.
enum SampleFixture {
    static func decoded(
        duration: TimeInterval = 4,
        sampleRate: Double = 48_000,
        level: Float = 0.5
    ) -> DecodedSample {
        let frames: Int = Int(duration * sampleRate)
        let channel: [Float] = Array(repeating: level, count: frames)
        return .init(
            sampleRate: sampleRate,
            channels: [channel, channel],
            waveform: Array(repeating: 1, count: 64),
            isTruncated: false
        )
    }

    static func silent(duration: TimeInterval = 4) -> DecodedSample {
        decoded(duration: duration, level: 0)
    }

    static func info(tempo: Tempo? = nil, duration: TimeInterval = 4) -> SampleInfo {
        let detected: DetectedTempo? = tempo.map { DetectedTempo(tempo: $0, source: .fileName) }
        return .init(duration: duration, tempo: detected)
    }
}
