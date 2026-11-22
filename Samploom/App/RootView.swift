import SamploomDomain
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @State private var viewModel: ImportViewModel = .init()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Spacing.xLarge) {
                header
                sampleCard
                gridCard
            }
            .padding(Metrics.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    @ViewBuilder
    private var gridCard: some View {
        switch viewModel.content {
        case .empty, .importing:
            EmptyView()
        case .imported:
            if let grid: MusicalGrid = viewModel.grid {
                sliceCard(grid: grid)
            }
        }
    }

    private func sliceCard(grid: MusicalGrid) -> some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Grid")
                    .font(Typography.title)
                    .foregroundStyle(.textPrimary)

                Spacer()

                Text("4/4")
                    .font(Typography.numeric)
                    .foregroundStyle(.textSecondary)
            }

            if let decoded: DecodedSample = viewModel.decoded {
                WaveformView(sample: decoded, plan: viewModel.plan)
                if decoded.isTruncated {
                    Text("Only the first \(Int(DecodedSample.maxDuration)) s of the file are used.")
                        .font(Typography.caption)
                        .foregroundStyle(.textSecondary)
                }
            }

            HStack(alignment: .center) {
                Text("Tempo")
                    .font(Typography.body)
                    .foregroundStyle(.textSecondary)

                Spacer()

                Text(tempoText)
                    .font(Typography.numeric)
                    .foregroundStyle(.textPrimary)

                Stepper("", value: $viewModel.tempoBPM, in: Tempo.supportedRange, step: 1)
                    .labelsHidden()
            }

            valueRow(title: "Bar", value: secondsText(grid.secondsPerBar))
            valueRow(title: "Step", value: secondsText(grid.step(for: viewModel.division)))

            VStack(alignment: .leading, spacing: Metrics.Spacing.xSmall) {
                HStack {
                    Text("Offset")
                        .font(Typography.body)
                        .foregroundStyle(.textSecondary)

                    Spacer()

                    Text(offsetText)
                        .font(Typography.numeric)
                        .foregroundStyle(.textPrimary)
                }

                Slider(value: $viewModel.gridOffset, in: 0...max(0.001, grid.secondsPerBar - 0.001))
                    .tint(.accent)
            }

            valueRow(title: "Repeat", value: "\(viewModel.repeats) × \(viewModel.barsPerSlice) bar")

            Divider()
                .background(.hairline)

            Picker("Grid division", selection: $viewModel.division) {
                ForEach(GridDivision.allCases, id: \.self) { division in
                    Text(divisionTitle(division)).tag(division)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker("Slice mode", selection: $viewModel.mode) {
                Text("Single").tag(SliceMode.single)
                Text("Random").tag(SliceMode.random)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let plan: SlicePlan = viewModel.plan, plan.isEmpty {
                Text("Every grid position is silent — nothing to slice.")
                    .font(Typography.caption)
                    .foregroundStyle(.textSecondary)
            } else {
                Button("Reshuffle") {
                    viewModel.reshuffle()
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("Slices are cut with \(fadeText) fades so the joins never click.")
                    .font(Typography.caption)
                    .foregroundStyle(.textSecondary)
            }

            Text(tempoSourceText)
                .font(Typography.caption)
                .foregroundStyle(.textSecondary)
        }
        .surface()
    }

    private func valueRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(.textSecondary)

            Spacer()

            Text(value)
                .font(Typography.numeric)
                .foregroundStyle(.textPrimary)
        }
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
        case .empty:
            return "No sample loaded"
        case .importing:
            return "Importing…"
        case .imported:
            return "Sample ready"
        }
    }

    private var cardSubtitle: String {
        switch viewModel.content {
        case .empty:
            return "Import a WAV, AIFF or MP3 file from Files."
        case .importing:
            return "Copying the file into the app."
        case .imported(let sample):
            guard let duration: TimeInterval = viewModel.info?.duration else { return sample.displayName }
            return "\(sample.displayName) · \(secondsText(duration))"
        }
    }

    private var tempoText: String {
        guard let tempo: Tempo = viewModel.grid?.tempo else { return "—" }
        return "\(tempo.beatsPerMinute.formatted()) BPM"
    }

    private var tempoSourceText: String {
        if viewModel.isTempoManual {
            return "Tempo set manually."
        }
        guard let source: DetectedTempo.Source = viewModel.info?.tempo?.source else {
            return "Tempo assumed: no BPM in the file tags or its name."
        }
        switch source {
        case .metadata:
            return "Tempo read from file tags."
        case .fileName:
            return "Tempo read from the file name."
        }
    }

    private var cardButtonTitle: String {
        switch viewModel.content {
        case .empty:
            return "Import sample"
        case .importing:
            return "Importing…"
        case .imported:
            return "Replace sample"
        }
    }

    private func divisionTitle(_ division: GridDivision) -> String {
        switch division {
        case .bar:
            return "Bar"
        case .beat:
            return "Beat"
        case .halfBeat:
            return "1/2"
        case .quarterBeat:
            return "1/4"
        }
    }

    private func secondsText(_ seconds: Double) -> String {
        String(format: "%.3f s", seconds)
    }

    private var fadeText: String {
        "\(Int((SliceRenderer.defaultFadeDuration * 1_000).rounded())) ms"
    }

    private var offsetText: String {
        "\(Int((viewModel.effectiveGridOffset * 1_000).rounded())) ms"
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
