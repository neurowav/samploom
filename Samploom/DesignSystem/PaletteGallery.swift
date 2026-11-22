#if DEBUG
import SwiftUI

/// Development-only gallery for checking the palette in both appearances.
struct PaletteGallery: View {
    private let tokens: [(name: String, color: Color)] = [
        ("backgroundPrimary", .backgroundPrimary),
        ("backgroundSecondary", .backgroundSecondary),
        ("textPrimary", .textPrimary),
        ("textSecondary", .textSecondary),
        ("hairline", .hairline),
        ("accent", .accent),
        ("onAccent", .onAccent),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Spacing.medium) {
                ForEach(tokens, id: \.name) { token in
                    HStack(spacing: Metrics.Spacing.medium) {
                        RoundedRectangle(cornerRadius: Metrics.Radius.chip)
                            .fill(token.color)
                            .frame(width: Metrics.Spacing.xxxLarge + Metrics.Spacing.small, height: Metrics.Spacing.xxLarge)
                            .overlay {
                                RoundedRectangle(cornerRadius: Metrics.Radius.chip)
                                    .strokeBorder(.hairline, lineWidth: Metrics.Stroke.hairline)
                            }

                        Text(token.name)
                            .font(Typography.numeric)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            .padding(Metrics.Spacing.large)
        }
        .background(.backgroundPrimary)
    }
}

#Preview("Palette — light") {
    PaletteGallery()
        .preferredColorScheme(.light)
}

#Preview("Palette — dark") {
    PaletteGallery()
        .preferredColorScheme(.dark)
}
#endif
