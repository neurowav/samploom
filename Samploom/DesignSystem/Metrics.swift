import CoreGraphics

/// Spacing, corner radii and stroke widths.
///
/// One scale for the whole app keeps rhythm consistent and makes layout
/// reviewable: if a number is not in here, it probably should not exist.
enum Metrics {
    enum Spacing {
        static let xxSmall: CGFloat = 2
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
        static let xxxLarge: CGFloat = 48
    }

    enum Radius {
        static let chip: CGFloat = 8
        static let card: CGFloat = 16
        static let sheet: CGFloat = 24
    }

    enum Stroke {
        static let hairline: CGFloat = 1
    }
}
