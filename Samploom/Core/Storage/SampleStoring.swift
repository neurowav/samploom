import Foundation

/// Storage boundary, so tests can substitute their own implementation.
nonisolated protocol SampleStoring: Sendable {
    func importFile(at sourceURL: URL) async throws -> ImportedSample
    func remove(_ sample: ImportedSample) async throws
}

extension SampleStorage: SampleStoring {}
