import Foundation
import Observation
import SamploomDomain

@Observable
@MainActor
final class ImportViewModel {
    enum Content: Equatable {
        case empty
        case importing
        case imported(ImportedSample)
    }

    private(set) var content: Content = .empty
    private(set) var info: SampleInfo?
    private(set) var decoded: DecodedSample?
    var isImporterPresented: Bool = false
    var errorMessage: String?
    var division: GridDivision = .bar
    var mode: SliceMode = .single
    /// Moves the grid origin inside the bar, for samples that do not start on a downbeat.
    var gridOffset: TimeInterval = 0
    private(set) var seed: UInt64 = .random(in: UInt64.min...UInt64.max)
    /// Set when the user types a tempo; cleared on the next import.
    private(set) var manualTempo: Tempo?

    let barsPerSlice: Int = 1
    let repeats: Int = 4

    private let storage: SampleStorage
    private let inspector: SampleInspector
    private let decoder: SampleDecoder
    private let planner: SlicePlanner = .init()
    private var currentSample: ImportedSample?

    init(
        storage: SampleStorage = .init(),
        inspector: SampleInspector = .init(),
        decoder: SampleDecoder = .init()
    ) {
        self.storage = storage
        self.inspector = inspector
        self.decoder = decoder
    }

    /// Grid for the loaded sample. When the file carries no tempo the app keeps
    /// working with an assumed one instead of blocking the slice step.
    var grid: MusicalGrid? {
        guard let info else { return nil }
        return .init(tempo: manualTempo ?? info.tempo?.tempo ?? .assumed)
    }

    var isTempoAssumed: Bool {
        info != nil && manualTempo == nil && info?.tempo == nil
    }

    var isTempoManual: Bool {
        manualTempo != nil
    }

    /// Tempo shown and edited on screen; out-of-range input is clamped.
    var tempoBPM: Double {
        get { grid?.tempo.beatsPerMinute ?? Tempo.assumed.beatsPerMinute }
        set {
            let range: ClosedRange<Double> = Tempo.supportedRange
            let clamped: Double = min(max(newValue, range.lowerBound), range.upperBound)
            manualTempo = try? .init(beatsPerMinute: clamped)
        }
    }

    /// Offset actually used by the plan: the slider can keep a stale value when
    /// the tempo changes and the bar gets shorter.
    var effectiveGridOffset: TimeInterval {
        guard let grid else { return 0 }
        let limit: TimeInterval = max(0, grid.secondsPerBar - 0.001)
        return min(max(0, gridOffset), limit)
    }

    /// Slice plan for the current settings, or `nil` while audio is still decoding.
    var plan: SlicePlan? {
        guard let grid, let decoded else { return nil }
        let sliceLength: TimeInterval = grid.seconds(forBars: barsPerSlice)
        return planner.plan(
            mode: mode,
            grid: grid,
            duration: decoded.duration,
            barsPerSlice: barsPerSlice,
            repeats: repeats,
            division: division,
            seed: seed,
            offset: effectiveGridOffset,
            isSilent: { start in
                decoded.isSilent(startingAt: start, length: sliceLength, wraps: true)
            }
        )
    }

    func chooseSample() {
        isImporterPresented = true
    }

    func reshuffle() {
        seed = .random(in: UInt64.min...UInt64.max)
    }

    func handlePickedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importSample(from: url)
        case .failure(let error):
            // Dismissing the picker is not an error worth alerting about.
            guard (error as NSError).code != NSUserCancelledError else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func importSample(from url: URL) {
        content = .importing
        info = nil
        decoded = nil
        manualTempo = nil
        gridOffset = 0
        Task {
            do {
                let sample: ImportedSample = try await storage.importFile(at: url)
                await discardCurrentSample()
                currentSample = sample
                content = .imported(sample)
                await analyse(sample)
            } catch {
                content = currentSample.map(Content.imported) ?? .empty
                errorMessage = error.localizedDescription
            }
        }
    }

    private func analyse(_ sample: ImportedSample) async {
        let inspected: SampleInfo? = try? await inspector.inspect(
            fileAt: sample.url,
            originalFileName: sample.displayName
        )
        let decodedSample: DecodedSample? = try? await decoder.decode(fileAt: sample.url)
        guard currentSample == sample else { return }
        info = inspected
        decoded = decodedSample
    }

    /// Keeps a single sample around: replacing it must not leave orphaned copies.
    private func discardCurrentSample() async {
        guard let currentSample else { return }
        try? await storage.remove(currentSample)
        self.currentSample = nil
    }
}
