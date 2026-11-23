import Foundation

/// Where the slices of one loop sit in the sample.
public struct SlicePlan: Hashable, Sendable {
    /// Length of one slice in seconds.
    public let sliceLength: TimeInterval
    /// Start of every repeat, in seconds from the beginning of the sample.
    public let starts: [TimeInterval]

    public init(sliceLength: TimeInterval, starts: [TimeInterval]) {
        self.sliceLength = sliceLength
        self.starts = starts
    }

    public var isEmpty: Bool {
        starts.isEmpty
    }

    /// Repeats the starts cyclically until the plan has `count` slices.
    ///
    /// This is how a short generated loop fills a longer pass: four slices
    /// repeated four times make sixteen. When `count` is not a multiple of the
    /// pattern, the last loop is simply cut short.
    public func repeated(to count: Int) -> SlicePlan {
        guard !starts.isEmpty, count > 0 else {
            return .init(sliceLength: sliceLength, starts: [])
        }
        let tiled: [TimeInterval] = (0..<count).map { starts[$0 % starts.count] }
        return .init(sliceLength: sliceLength, starts: tiled)
    }
}
