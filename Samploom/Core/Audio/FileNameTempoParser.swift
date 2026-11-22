import Foundation
import SamploomDomain

/// Reads tempo from file names in the wild, for example
/// `Artist_Track_128BPM_Cmin.wav` or `kick_120_.wav`.
nonisolated struct FileNameTempoParser: Sendable {
    func tempo(inFileName fileName: String) -> Tempo? {
        let candidates: [Substring?] = [
            fileName.firstMatch(of: /(?i)(\d{2,3})\s?bpm/)?.1,
            fileName.firstMatch(of: /(?:^|_)(\d{2,3})(?:_|\.|$)/)?.1
        ]
        for candidate in candidates {
            guard let candidate else { continue }
            guard let beatsPerMinute: Double = .init(candidate) else { continue }
            if let tempo: Tempo = try? .init(beatsPerMinute: beatsPerMinute) {
                return tempo
            }
        }
        return nil
    }
}
