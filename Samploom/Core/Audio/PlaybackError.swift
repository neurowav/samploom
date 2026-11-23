import Foundation

/// Failures of the playback layer that the screen can explain in words.
nonisolated enum PlaybackError: LocalizedError, Equatable {
    case unsupportedFormat
    case bufferAllocationFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This sample's format cannot be played."
        case .bufferAllocationFailed:
            return "The player could not prepare the audio buffers."
        }
    }
}
