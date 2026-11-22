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
    var isImporterPresented: Bool = false
    var errorMessage: String?
    var division: GridDivision = .bar

    private let storage: SampleStorage
    private let inspector: SampleInspector
    private var currentSample: ImportedSample?

    init(storage: SampleStorage = .init(), inspector: SampleInspector = .init()) {
        self.storage = storage
        self.inspector = inspector
    }

    /// Grid for the loaded sample, or `nil` while there is no detected tempo.
    var grid: MusicalGrid? {
        guard let tempo: Tempo = info?.tempo?.tempo else { return nil }
        return .init(tempo: tempo)
    }

    func chooseSample() {
        isImporterPresented = true
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
        Task {
            do {
                let sample: ImportedSample = try await storage.importFile(at: url)
                await discardCurrentSample()
                currentSample = sample
                content = .imported(sample)
                await inspect(sample)
            } catch {
                content = currentSample.map(Content.imported) ?? .empty
                errorMessage = error.localizedDescription
            }
        }
    }

    private func inspect(_ sample: ImportedSample) async {
        let inspected: SampleInfo? = try? await inspector.inspect(
            fileAt: sample.url,
            originalFileName: sample.displayName
        )
        guard currentSample == sample else { return }
        info = inspected
    }

    /// Keeps a single sample around: replacing it must not leave orphaned copies.
    private func discardCurrentSample() async {
        guard let currentSample else { return }
        try? await storage.remove(currentSample)
        self.currentSample = nil
    }
}
