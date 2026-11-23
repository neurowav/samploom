/// Musical time grid of a sample: tempo plus meter.
public struct MusicalGrid: Hashable, Sendable {
    public let tempo: Tempo
    public let timeSignature: TimeSignature

    public init(tempo: Tempo, timeSignature: TimeSignature = .fourFour) {
        self.tempo = tempo
        self.timeSignature = timeSignature
    }

    public var secondsPerBeat: Double {
        60 / tempo.beatsPerMinute
    }

    public var secondsPerBar: Double {
        secondsPerBeat * Double(timeSignature.beatsPerBar)
    }

    public func seconds(forBars bars: Int) -> Double {
        secondsPerBar * Double(bars)
    }

    /// Length of one step of the grid.
    public func step(for division: GridDivision) -> Double {
        switch division {
        case .bar:
            return secondsPerBar
        case .halfBar:
            return secondsPerBar / 2
        case .beat:
            return secondsPerBeat
        case .halfBeat:
            return secondsPerBeat / 2
        case .quarterBeat:
            return secondsPerBeat / 4
        }
    }

    /// Rounds a time down to the nearest grid step.
    public func quantized(_ seconds: Double, to division: GridDivision) -> Double {
        let step: Double = step(for: division)
        guard step > 0 else { return 0 }
        return (seconds / step).rounded(.down) * step
    }
}
