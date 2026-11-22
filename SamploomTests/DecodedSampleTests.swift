import Foundation
import Testing

@testable import Samploom

@Suite("DecodedSample")
struct DecodedSampleTests {
    private let silentSample: DecodedSample = .init(
        sampleRate: 100,
        channels: [Array(repeating: 0, count: 100)],
        waveform: [],
        isTruncated: false
    )

    @Test("Digital silence is detected")
    func detectsSilence() {
        #expect(silentSample.isSilent(startingAt: 0, length: 1))
        #expect(silentSample.isSilent(startingAt: 0.5, length: 0.5))
    }

    @Test("A window with a tone is not silent")
    func detectsTone() {
        var channel: [Float] = Array(repeating: 0, count: 100)
        channel[80] = 0.5
        let decoded: DecodedSample = .init(sampleRate: 100, channels: [channel], waveform: [], isTruncated: false)
        #expect(decoded.isSilent(startingAt: 0, length: 0.5))
        #expect(decoded.isSilent(startingAt: 0.75, length: 0.25) == false)
    }

    @Test("Audible content in either channel keeps the window alive")
    func outOfPhaseStereoIsNotSilent() {
        var left: [Float] = Array(repeating: 0, count: 100)
        var right: [Float] = Array(repeating: 0, count: 100)
        left[10] = 0.5
        right[10] = -0.5
        let decoded: DecodedSample = .init(sampleRate: 100, channels: [left, right], waveform: [], isTruncated: false)
        #expect(decoded.isSilent(startingAt: 0, length: 0.5) == false)
    }

    @Test("A window outside the sample is treated as silent")
    func outsideTheSample() {
        #expect(silentSample.isSilent(startingAt: 2, length: 1))
        #expect(silentSample.isSilent(startingAt: 0.9, length: 0.05))
    }

    @Test("Duration follows the frame count")
    func duration() {
        let decoded: DecodedSample = .init(
            sampleRate: 100,
            channels: [Array(repeating: 0, count: 250)],
            waveform: [],
            isTruncated: false
        )
        #expect(decoded.duration == 2.5)
    }
}
