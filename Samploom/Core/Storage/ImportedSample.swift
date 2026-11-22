import Foundation

/// A sample that has been copied into the app sandbox.
nonisolated struct ImportedSample: Identifiable, Hashable, Sendable {
    let id: UUID
    /// Location inside the app container, never the original picker URL.
    let url: URL
    /// File name as the user saw it in Files.
    let displayName: String
    let importedAt: Date
}
