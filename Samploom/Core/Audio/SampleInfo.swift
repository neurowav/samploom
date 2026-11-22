import Foundation
import SamploomDomain

/// What the app knows about an imported sample after reading the file.
nonisolated struct SampleInfo: Hashable, Sendable {
    let duration: TimeInterval
    let tempo: DetectedTempo?
}

/// Tempo found in a sample, together with the place it came from.
nonisolated struct DetectedTempo: Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case metadata
        case fileName
    }

    let tempo: Tempo
    let source: Source
}
