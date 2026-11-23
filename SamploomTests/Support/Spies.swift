import Foundation
import SamploomDomain

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

/// Player that records the slices it was given and lets a test deliver the
/// boundary events itself. Keeping the callbacks after `stop()` reproduces the
/// node reporting buffered slices after it has been stopped.
@MainActor
final class PlayerSpy: SlicePlaying {
    private(set) var slices: [[SliceAudio]] = []
    private(set) var callbacks: [@MainActor (PlaybackEvent) -> Void] = []
    private(set) var stopCount: Int = 0
    var failure: (any Error)?

    func play(
        _ slices: [SliceAudio],
        onEvent: @escaping @MainActor (PlaybackEvent) -> Void
    ) async throws {
        if let failure {
            throw failure
        }
        self.slices.append(slices)
        callbacks.append(onEvent)
    }

    func stop() {
        stopCount += 1
    }

    /// Delivers an event to a pass: the latest one unless a test says otherwise.
    func send(_ event: PlaybackEvent, pass: Int? = nil) {
        let index: Int = pass ?? callbacks.count - 1
        guard callbacks.indices.contains(index) else { return }
        callbacks[index](event)
    }
}
