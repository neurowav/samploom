import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @State private var viewModel: ImportViewModel = .init()

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xLarge) {
            header
            sampleCard
            Spacer(minLength: 0)
        }
        .padding(Metrics.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.backgroundPrimary)
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: [.audio]
        ) { result in
            viewModel.handlePickedFile(result)
        }
        .alert("Import failed", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
            Text("Samploom")
                .font(Typography.display)
                .foregroundStyle(.textPrimary)

            Text("Slice a sample by the musical grid and jam with it.")
                .font(Typography.callout)
                .foregroundStyle(.textSecondary)
        }
    }

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
            HStack(alignment: .top, spacing: Metrics.Spacing.medium) {
                statusIcon

                VStack(alignment: .leading, spacing: Metrics.Spacing.xxSmall) {
                    Text(cardTitle)
                        .font(Typography.headline)
                        .foregroundStyle(.textPrimary)

                    Text(cardSubtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }

            Button(cardButtonTitle) {
                viewModel.chooseSample()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.content == .importing)
        }
        .surface()
    }

    private var statusIcon: some View {
        Group {
            if viewModel.content == .importing {
                ProgressView()
                    .tint(.accent)
            } else {
                Image(systemName: viewModel.content == .empty ? "waveform" : "checkmark.circle.fill")
                    .font(.system(.title2))
                    .foregroundStyle(.accent)
            }
        }
        .frame(width: Metrics.Spacing.xxLarge, height: Metrics.Spacing.xxLarge)
    }

    private var cardTitle: String {
        switch viewModel.content {
        case .empty: "No sample loaded"
        case .importing: "Importing…"
        case .imported: "Sample ready"
        }
    }

    private var cardSubtitle: String {
        switch viewModel.content {
        case .empty: "Import a WAV, AIFF or MP3 file from Files."
        case .importing: "Copying the file into the app."
        case .imported(let sample): sample.displayName
        }
    }

    private var cardButtonTitle: String {
        switch viewModel.content {
        case .empty: "Import sample"
        case .importing: "Importing…"
        case .imported: "Replace sample"
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

#Preview {
    RootView()
}
