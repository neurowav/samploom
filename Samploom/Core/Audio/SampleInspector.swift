import AVFoundation
import Foundation
import SamploomDomain

/// Reads duration and tempo out of an imported file.
///
/// Precedence is embedded tags first, then the original file name. Tempo
/// written into BWF `bext` or iXML chunks is not exposed by AVFoundation, so
/// WAV files carrying it there are not covered yet.
actor SampleInspector {
    private let fileNameParser: FileNameTempoParser = .init()

    func inspect(fileAt url: URL, originalFileName: String) async throws -> SampleInfo {
        let asset: AVURLAsset = .init(url: url)
        let duration: CMTime = try await asset.load(.duration)
        let metadata: [AVMetadataItem] = try await asset.load(.metadata)
        let tagTempo: Tempo? = try await tempo(in: metadata)
        let detectedTempo: DetectedTempo? = tagTempo.map { DetectedTempo(tempo: $0, source: .metadata) }
            ?? fileNameParser.tempo(inFileName: originalFileName).map { DetectedTempo(tempo: $0, source: .fileName) }
        let seconds: TimeInterval = duration.isValid && !duration.isIndefinite ? duration.seconds : 0
        return .init(duration: seconds, tempo: detectedTempo)
    }

    private func tempo(in metadata: [AVMetadataItem]) async throws -> Tempo? {
        let items: [AVMetadataItem] = metadata.filter { $0.identifier == .id3MetadataBeatsPerMinute }
        for item in items {
            let value: String? = try await item.load(.stringValue)
            guard let value else { continue }
            guard let beatsPerMinute: Double = .init(value.trimmingCharacters(in: .whitespaces)) else { continue }
            if let tempo: Tempo = try? .init(beatsPerMinute: beatsPerMinute) {
                return tempo
            }
        }
        return nil
    }
}
