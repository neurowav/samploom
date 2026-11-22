/// Meter of a bar.
///
/// Only 4/4 is used by the app today; the values are kept general so other
/// meters do not need a type change later.
public struct TimeSignature: Hashable, Sendable {
    public static let fourFour: TimeSignature = .init(beatsPerBar: 4, beatUnit: 4)

    /// Beats in one bar.
    public let beatsPerBar: Int
    /// Note value that counts as one beat: 4 means a quarter note.
    public let beatUnit: Int

    public init(beatsPerBar: Int, beatUnit: Int) {
        self.beatsPerBar = beatsPerBar
        self.beatUnit = beatUnit
    }
}
