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

    private(set) var loaded: LoadedSample?
    private(set) var content: Content = .empty
    var isImporterPresented: Bool = false
    var errorMessage: String?
    var division: GridDivision = .bar
    var mode: SliceMode = .single
    /// Moves the grid origin inside the bar, for samples that do not start on a downbeat.
    var gridOffset: TimeInterval = 0
    /// How many times the selected slice is repeated in one pass.
    let repeats: Int = 4
    private(set) var seed: UInt64 = .random(in: UInt64.min...UInt64.max)
    /// Set when the user types a tempo; cleared on the next import.
    private(set) var manualTempo: Tempo?

    private let storage: any SampleStoring
    private let inspector: any SampleInspecting
    private let decoder: any SampleDecoding
    private let planner: SlicePlanner = .init()
    private var importTask: Task<Void, Never>?

    init(
        storage: any SampleStoring = SampleStorage(),
        inspector: any SampleInspecting = SampleInspector(),
        decoder: any SampleDecoding = SampleDecoder()
    ) {
        self.storage = storage
        self.inspector = inspector
        self.decoder = decoder
    }

    var currentSample: ImportedSample? {
        loaded?.sample
    }

    var info: SampleInfo? {
        loaded?.info
    }

    var decoded: DecodedSample? {
        loaded?.decoded
    }

    /// Grid for the loaded sample. When the file carries no tempo the app keeps
    /// working with an assumed one instead of blocking the slice step.
    var grid: MusicalGrid? {
        guard let info else { return nil }
        return .init(tempo: manualTempo ?? info.tempo?.tempo ?? .assumed)
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
        // The selected division is both the grid step and the slice length.
        let sliceLength: TimeInterval = grid.step(for: division)
        return planner.plan(
            mode: mode,
            grid: grid,
            duration: decoded.duration,
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
        guard content != .importing else { return }
        isImporterPresented = true
    }

    func reshuffle() {
        seed = .random(in: UInt64.min...UInt64.max)
    }

    func handlePickedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            startImport(from: url)
        case .failure(let error):
            // Dismissing the picker is not an error worth alerting about.
            guard (error as NSError).code != NSUserCancelledError else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Copies, inspects and decodes the file. Awaitable on purpose: callers and
    /// tests get the finished state instead of polling for it.
    func importSample(from url: URL) async {
        content = .importing
        var copied: ImportedSample?
        do {
            let sample: ImportedSample = try await storage.importFile(at: url)
            copied = sample
            try Task.checkCancellation()
            let inspected: SampleInfo? = try? await inspector.inspect(
                fileAt: sample.url,
                originalFileName: sample.displayName
            )
            try Task.checkCancellation()
            let decodedSample: DecodedSample? = try? await decoder.decode(fileAt: sample.url)
            try Task.checkCancellation()
            let previous: ImportedSample? = loaded?.sample
            loaded = .init(sample: sample, info: inspected, decoded: decodedSample)
            manualTempo = nil
            gridOffset = 0
            if let previous {
                try? await storage.remove(previous)
            }
            content = .imported(sample)
        } catch {
            if let copied, loaded?.sample != copied {
                try? await storage.remove(copied)
            }
            content = loaded.map { .imported($0.sample) } ?? .empty
            if !(error is CancellationError) {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Test seam: waits for the import that was started from the picker.
    func awaitPendingImport() async {
        await importTask?.value
    }

    private func startImport(from url: URL) {
        // A newer pick wins: the previous import stops where it is.
        importTask?.cancel()
        importTask = Task { await importSample(from: url) }
    }
}
