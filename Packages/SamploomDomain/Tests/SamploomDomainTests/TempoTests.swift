import Testing

@testable import SamploomDomain

@Suite("Tempo")
struct TempoTests {
    @Test("A normal tempo keeps its value")
    func validTempo() throws {
        let tempo: Tempo = try .init(beatsPerMinute: 128)
        #expect(tempo.beatsPerMinute == 128)
    }

    @Test("Tempo below the supported range is rejected")
    func tooSlow() {
        #expect(throws: Tempo.ValidationError.outOfRange(10)) {
            try Tempo(beatsPerMinute: 10)
        }
    }

    @Test("Tempo above the supported range is rejected")
    func tooFast() {
        #expect(throws: Tempo.ValidationError.outOfRange(500)) {
            try Tempo(beatsPerMinute: 500)
        }
    }
}
