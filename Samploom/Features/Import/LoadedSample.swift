import Foundation

/// The sample on screen together with everything read from it.
///
/// The three parts are replaced in one assignment, so the name, duration, grid
/// and waveform can never update at different moments and make the screen flicker.
nonisolated struct LoadedSample: Sendable {
    let sample: ImportedSample
    let info: SampleInfo?
    let decoded: DecodedSample?
}
