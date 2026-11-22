import Foundation
import Testing

@testable import Samploom

@Suite("DecodedSample")
struct DecodedSampleTests {
    private let silentSample: DecodedSample = .init(
        duration: 1,
        sampleRate: 100,
        waveform: [],
        samples: Array(repeating: 0, count: 100)
    )

    @Test("Digital silence is detected")
    func detectsSilence() {
        #expect(silentSample.isSilent(startingAt: 0, length: 1))
        #expect(silentSample.isSilent(startingAt: 0.5, length: 0.5))
    }

    @Test("A window with a tone is not silent")
    func detectsTone() {
        var samples: [Float] = Array(repeating: 0, count: 100)
        samples[80] = 0.5
        let decoded: DecodedSample = .init(duration: 1, sampleRate: 100, waveform: [], samples: samples)
        #expect(decoded.isSilent(startingAt: 0, length: 0.5))
        #expect(decoded.isSilent(startingAt: 0.75, length: 0.25) == false)
    }

    @Test("A window outside the sample is treated as silent")
    func outsideTheSample() {
        #expect(silentSample.isSilent(startingAt: 2, length: 1))
        #expect(silentSample.isSilent(startingAt: 0.9, length: 0.05))
    }
}
