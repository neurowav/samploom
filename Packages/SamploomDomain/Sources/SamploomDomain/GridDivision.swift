/// Step of the musical grid used to place slice starts.
///
/// Random positions must land on one of these steps, otherwise slices stop
/// sounding like part of the sample.
public enum GridDivision: String, CaseIterable, Sendable {
    case bar
    case beat
    case halfBeat
    case quarterBeat
}
