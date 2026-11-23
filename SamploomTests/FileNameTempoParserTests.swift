import Foundation
import Testing

@testable import Samploom

@Suite("FileNameTempoParser", .timeLimit(.minutes(1)))
struct FileNameTempoParserTests {
    private let parser: FileNameTempoParser = .init()

    @Test("Splice style name with a BPM suffix")
    func bpmSuffix() {
        #expect(parser.tempo(inFileName: "Artist_Track_128BPM_Cmin.wav")?.beatsPerMinute == 128)
    }

    @Test("BPM written as a separate word")
    func spacedBPM() {
        #expect(parser.tempo(inFileName: "loop 174 bpm.wav")?.beatsPerMinute == 174)
    }

    @Test("Numeric segment between underscores")
    func underscoreSegment() {
        #expect(parser.tempo(inFileName: "kick_120_.wav")?.beatsPerMinute == 120)
    }

    @Test("Name without a tempo gives nothing")
    func noTempo() {
        #expect(parser.tempo(inFileName: "hat.wav") == nil)
    }

    @Test("Value outside the supported range is ignored")
    func outOfRange() {
        #expect(parser.tempo(inFileName: "test_999_.wav") == nil)
    }

    @Test("Dates in the name are not mistaken for a tempo")
    func datesAreIgnored() {
        #expect(parser.tempo(inFileName: "session_2024_05_01.wav") == nil)
    }
}
