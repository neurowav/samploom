import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.xLarge) {
            header
            importCard
            Spacer(minLength: 0)
        }
        .padding(Metrics.Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.backgroundPrimary)
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

    private var importCard: some View {
        VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
            HStack(spacing: Metrics.Spacing.medium) {
                Image(systemName: "waveform")
                    .font(.system(.title2))
                    .foregroundStyle(.accent)

                VStack(alignment: .leading, spacing: Metrics.Spacing.xxSmall) {
                    Text("No sample loaded")
                        .font(Typography.headline)
                        .foregroundStyle(.textPrimary)

                    Text("Import a WAV, AIFF or MP3 file from Files.")
                        .font(Typography.caption)
                        .foregroundStyle(.textSecondary)
                }
            }

            Button("Import sample") {
                // TODO: present the document picker once the import feature lands.
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .surface()
    }
}

#Preview {
    RootView()
}
