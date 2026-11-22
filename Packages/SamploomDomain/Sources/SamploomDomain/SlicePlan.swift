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
}
