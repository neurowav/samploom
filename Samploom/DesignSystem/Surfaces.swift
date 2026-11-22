import SwiftUI

/// Raised container used for cards and panels.
struct SurfaceModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.backgroundSecondary, in: .rect(cornerRadius: Metrics.Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.Radius.card)
                    .strokeBorder(.hairline, lineWidth: Metrics.Stroke.hairline)
            }
    }
}

extension View {
    func surface(padding: CGFloat = Metrics.Spacing.large) -> some View {
        modifier(SurfaceModifier(padding: padding))
    }
}

/// Primary action: filled with the accent colour, full width inside its container.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metrics.Spacing.medium)
            .background(.accent, in: .rect(cornerRadius: Metrics.Radius.chip))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
