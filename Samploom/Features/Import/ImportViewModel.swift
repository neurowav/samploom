import Foundation
import Observation

@Observable
@MainActor
final class ImportViewModel {
    enum Content: Equatable {
        case empty
        case importing
        case imported(ImportedSample)
    }

    private(set) var content: Content = .empty
    var isImporterPresented = false
    var errorMessage: String?

    private let storage: SampleStorage
    private var currentSample: ImportedSample?

    init(storage: SampleStorage = SampleStorage()) {
        self.storage = storage
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

        Task {
            do {
                let sample = try await storage.importFile(at: url)
                await discardCurrentSample()
                currentSample = sample
                content = .imported(sample)
            } catch {
                content = currentSample.map(Content.imported) ?? .empty
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Keeps a single sample around: replacing it must not leave orphaned copies.
    private func discardCurrentSample() async {
        guard let currentSample else { return }
        try? await storage.remove(currentSample)
        self.currentSample = nil
    }
}
