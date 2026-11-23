import Foundation

/// Reads a file into samples. Behind a protocol so tests can control when the
/// work finishes instead of waiting on it.
nonisolated protocol SampleDecoding: Sendable {
    func decode(fileAt url: URL) async throws -> DecodedSample
}

/// Reads duration and tempo out of a file.
nonisolated protocol SampleInspecting: Sendable {
    func inspect(fileAt url: URL, originalFileName: String) async throws -> SampleInfo
}

extension SampleInspector: SampleInspecting {}

extension SampleDecoder: SampleDecoding {
    func decode(fileAt url: URL) async throws -> DecodedSample {
        try decode(
            fileAt: url,
            waveformBins: 512,
            maxDuration: DecodedSample.maxDuration
        )
    }
}
