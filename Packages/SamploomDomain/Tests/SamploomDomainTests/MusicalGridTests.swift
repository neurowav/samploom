import Foundation
import Testing

@testable import SamploomDomain

@Suite("MusicalGrid")
struct MusicalGridTests {
    @Test("128 BPM in 4/4 gives the documented bar length")
    func barLength() throws {
        let grid: MusicalGrid = .init(tempo: try .init(beatsPerMinute: 128))
        #expect(grid.secondsPerBeat == 60.0 / 128.0)
        #expect(grid.secondsPerBar == 1.875)
        #expect(grid.seconds(forBars: 4) == 7.5)
    }

    @Test("Each division returns its share of a bar")
    func divisionSteps() throws {
        let grid: MusicalGrid = .init(tempo: try .init(beatsPerMinute: 120))
        #expect(grid.step(for: .bar) == 2.0)
        #expect(grid.step(for: .beat) == 0.5)
        #expect(grid.step(for: .halfBeat) == 0.25)
        #expect(grid.step(for: .quarterBeat) == 0.125)
    }

    @Test("Quantising snaps a time down to the grid")
    func quantisation() throws {
        let grid: MusicalGrid = .init(tempo: try .init(beatsPerMinute: 120))
        #expect(grid.quantized(0.6, to: .beat) == 0.5)
        #expect(grid.quantized(1.99, to: .bar) == 0)
        #expect(grid.quantized(2.0, to: .bar) == 2.0)
        #expect(grid.quantized(2.1, to: .bar) == 2.0)
    }
}
