import Foundation

/// Places slice starts on the musical grid.
///
/// Only positions on a grid step are candidates, otherwise a random start
/// would sound like a piece cut out at an arbitrary moment. The caller decides
/// what counts as an unusable slice — in the app that is a slice with no
/// audible content — and the planner simply skips such positions.
///
/// The division is also the slice length: a bar division cuts bars, a quarter-
/// beat division cuts quarter-beat cells. This keeps the windows on screen the
/// same size as the audio they produce, and making the division finer really
/// does make the slice shorter.
public struct SlicePlanner: Sendable {
    public init() {}

    public func plan(
        mode: SliceMode,
        grid: MusicalGrid,
        duration: TimeInterval,
        repeats: Int = 4,
        division: GridDivision = .bar,
        seed: UInt64,
        offset: TimeInterval = 0,
        isSilent: (TimeInterval) -> Bool = { _ in false }
    ) -> SlicePlan {
        let step: TimeInterval = grid.step(for: division)
        let sliceLength: TimeInterval = step
        let repeatCount: Int = max(1, repeats)
        let gridOffset: TimeInterval = max(0, offset)
        guard step > 0, duration > gridOffset else {
            return .init(sliceLength: sliceLength, starts: [])
        }
        // Starts must sit inside the file; a slice may run past its end and wrap.
        let capacity: Int = Int(((duration - gridOffset) / step).rounded(.up))
        var generator: SeededGenerator = .init(seed: seed)
        let order: [Int] = Array(0..<capacity).shuffled(using: &generator)
        var validStarts: [TimeInterval] = []
        for index in order {
            let start: TimeInterval = gridOffset + Double(index) * step
            if isSilent(start) { continue }
            validStarts.append(start)
            if mode == .single || validStarts.count == repeatCount {
                break
            }
        }
        guard let firstStart: TimeInterval = validStarts.first else {
            return .init(sliceLength: sliceLength, starts: [])
        }
        switch mode {
        case .single:
            return .init(sliceLength: sliceLength, starts: Array(repeating: firstStart, count: repeatCount))
        case .random:
            let starts: [TimeInterval] = (0..<repeatCount).map { offset in
                validStarts[offset % validStarts.count]
            }
            return .init(sliceLength: sliceLength, starts: starts)
        }
    }
}
