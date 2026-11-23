import Foundation
import Testing

@testable import SamploomDomain

@Suite("SlicePlan")
struct SlicePlanTests {
    private let loop: SlicePlan = .init(sliceLength: 2, starts: [0, 2, 4, 6])

    @Test("A whole number of loops fills the pass")
    func wholeLoops() {
        let plan: SlicePlan = loop.repeated(to: 16)
        #expect(plan.starts.count == 16)
        #expect(Array(plan.starts[0..<4]) == [0, 2, 4, 6])
        #expect(Array(plan.starts[4..<8]) == [0, 2, 4, 6])
        #expect(Array(plan.starts[12..<16]) == [0, 2, 4, 6])
        #expect(plan.sliceLength == 2)
    }

    @Test("A partial last loop still fills the pass")
    func partialLoop() {
        let plan: SlicePlan = loop.repeated(to: 10)
        #expect(plan.starts.count == 10)
        #expect(Array(plan.starts[8..<10]) == [0, 2])
    }

    @Test("An empty pattern stays empty")
    func emptyPattern() {
        let empty: SlicePlan = .init(sliceLength: 2, starts: [])
        #expect(empty.repeated(to: 10).isEmpty)
        #expect(loop.repeated(to: 0).isEmpty)
    }
}
