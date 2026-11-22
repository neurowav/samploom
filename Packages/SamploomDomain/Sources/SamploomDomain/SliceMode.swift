/// How slice starts are chosen.
public enum SliceMode: String, CaseIterable, Sendable {
    /// One slice repeated: the same buffer plays over and over.
    case single
    /// A different slice per repeat, each start snapped to the grid.
    case random
}
