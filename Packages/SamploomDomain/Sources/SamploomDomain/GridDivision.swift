/// Step of the musical grid: the length of one slice and the positions its
/// start may land on.
///
/// Random positions must land on one of these steps, otherwise slices stop
/// sounding like part of the sample.
public enum GridDivision: String, CaseIterable, Sendable {
    case bar
    case halfBar
    case beat
    case halfBeat
    case quarterBeat
}
