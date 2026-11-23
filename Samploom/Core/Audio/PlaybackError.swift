import Foundation

/// Failures of the playback layer that the screen can explain in words.
nonisolated enum PlaybackError: LocalizedError, Equatable {
    case unsupportedFormat
    case inconsistentSlices
    case bufferAllocationFailed
    case sessionActivationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This sample's format cannot be played."
        case .inconsistentSlices:
            return "The slices do not share one format."
        case .bufferAllocationFailed:
            return "The player could not prepare the audio buffers."
        case .sessionActivationFailed:
            return "The audio session could not be started."
        }
    }
}
