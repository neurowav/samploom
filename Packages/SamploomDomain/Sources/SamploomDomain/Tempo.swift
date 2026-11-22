/// Musical tempo in beats per minute.
public struct Tempo: Hashable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case outOfRange(Double)
    }

    /// Range the app accepts. Slower values are usually a detection mistake,
    /// faster ones are not useful for slicing.
    public static let supportedRange: ClosedRange<Double> = 20...400

    /// Tempo used when a sample carries no BPM: 90 BPM keeps one-bar slices
    /// short enough for random starts to still feel musical.
    public static let assumed: Tempo = .init(uncheckedBeatsPerMinute: 90)

    public let beatsPerMinute: Double

    public init(beatsPerMinute: Double) throws {
        guard Self.supportedRange.contains(beatsPerMinute) else {
            throw ValidationError.outOfRange(beatsPerMinute)
        }
        self.beatsPerMinute = beatsPerMinute
    }

    private init(uncheckedBeatsPerMinute: Double) {
        self.beatsPerMinute = uncheckedBeatsPerMinute
    }
}
