import Foundation

@testable import Samploom

/// Inspector with a prepared answer, so screen tests do not depend on AVFoundation.
struct InspectorSpy: SampleInspecting {
    enum Failure: Error {
        case nothingPrepared
    }

    let info: SampleInfo?

    func inspect(fileAt url: URL, originalFileName: String) async throws -> SampleInfo {
        guard let info else { throw Failure.nothingPrepared }
        return info
    }
}

/// Decoder that returns a prepared sample immediately.
struct StubDecoder: SampleDecoding {
    let decoded: DecodedSample?

    func decode(fileAt url: URL) async throws -> DecodedSample {
        guard let decoded else { throw InspectorSpy.Failure.nothingPrepared }
        return decoded
    }
}

/// Decoder that hands out prepared results one at a time and blocks when nothing
/// is prepared. A test can look at the screen while the work is still in flight.
actor DecoderSpy: SampleDecoding {
    private var prepared: [Result<DecodedSample, any Error>] = []
    private var pending: CheckedContinuation<DecodedSample, any Error>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var decodeCalls: Int = 0

    func prepare(_ result: Result<DecodedSample, any Error>) {
        if let pending {
            self.pending = nil
            pending.resume(with: result)
            return
        }
        prepared.append(result)
    }

    /// Waits until a decode call is actually blocked on a prepared result.
    func waitUntilDecodeStarts() async {
        if pending != nil { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func decode(fileAt url: URL) async throws -> DecodedSample {
        decodeCalls += 1
        if !prepared.isEmpty {
            return try prepared.removeFirst().get()
        }
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        return try await withCheckedThrowingContinuation { continuation in
            if prepared.isEmpty {
                pending = continuation
            } else {
                continuation.resume(with: prepared.removeFirst())
            }
        }
    }
}
