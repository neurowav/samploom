import Foundation
import Testing

@testable import SamploomDomain

@Suite("SlicePlanner")
struct SlicePlannerTests {
    private let planner: SlicePlanner = .init()
    private let grid: MusicalGrid = .init(tempo: .assumed)

    @Test("Single mode repeats one grid-aligned start")
    func singleMode() {
        let plan: SlicePlan = planner.plan(
            mode: .single,
            grid: grid,
            duration: 8,
            repeats: 4,
            seed: 42
        )
        #expect(plan.starts.count == 4)
        #expect(Set(plan.starts).count == 1)
        #expect(plan.sliceLength == grid.secondsPerBar)
        let start: TimeInterval = plan.starts[0]
        #expect(isOnGrid(start, step: grid.step(for: .bar)))
        #expect(start + plan.sliceLength <= 8.000_001)
    }

    @Test("Random mode gives different starts on the grid")
    func randomMode() {
        let plan: SlicePlan = planner.plan(
            mode: .random,
            grid: grid,
            duration: 16,
            repeats: 4,
            division: .beat,
            seed: 7
        )
        #expect(plan.starts.count == 4)
        #expect(Set(plan.starts).count == 4)
        let step: TimeInterval = grid.step(for: .beat)
        for start in plan.starts {
            #expect(isOnGrid(start, step: step))
        }
    }

    @Test("The same seed produces the same plan")
    func determinism() {
        let first: SlicePlan = planner.plan(mode: .random, grid: grid, duration: 20, repeats: 4, seed: 99)
        let second: SlicePlan = planner.plan(mode: .random, grid: grid, duration: 20, repeats: 4, seed: 99)
        let other: SlicePlan = planner.plan(mode: .random, grid: grid, duration: 20, repeats: 4, seed: 100)
        #expect(first == second)
        #expect(first.starts != other.starts)
    }

    @Test("Silent positions are skipped")
    func silentPositionsAreSkipped() {
        let plan: SlicePlan = planner.plan(
            mode: .random,
            grid: grid,
            duration: 20,
            repeats: 4,
            seed: 5,
            isSilent: { start in start < 10 }
        )
        #expect(plan.starts.count == 4)
        #expect(plan.starts.allSatisfy { $0 >= 10 })
    }

    @Test("A fully silent sample gives no plan")
    func fullySilentSample() {
        let plan: SlicePlan = planner.plan(
            mode: .random,
            grid: grid,
            duration: 20,
            repeats: 4,
            seed: 5,
            isSilent: { _ in true }
        )
        #expect(plan.isEmpty)
    }

    @Test("A sample shorter than one slice still gets a plan from the start")
    func shortSample() {
        let plan: SlicePlan = planner.plan(mode: .single, grid: grid, duration: 0.5, repeats: 4, seed: 1)
        #expect(plan.starts == [0, 0, 0, 0])
    }

    /// Floating point: a start can land a hair below the step, so compare both sides.
    private func isOnGrid(_ time: TimeInterval, step: TimeInterval) -> Bool {
        let remainder: TimeInterval = time.truncatingRemainder(dividingBy: step)
        return min(remainder, step - remainder) < 0.000_001
    }
}
