import SwiftUI

/// Typography roles built on semantic text styles.
///
/// Sizes come from the text style, so Dynamic Type keeps working. Custom fonts,
/// when they appear, attach to the same styles via `Font.custom(_:size:relativeTo:)`
/// and every call site stays unchanged.
enum Typography {
    /// App name and other hero text.
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Screen titles.
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    /// Section headings and card titles.
    static let headline = Font.system(.headline)
    /// Running text.
    static let body = Font.system(.body)
    /// Supporting text next to a title.
    static let callout = Font.system(.callout)
    /// Captions, hints, metadata.
    static let caption = Font.system(.caption)
    /// BPM, timecodes, slice indices: monospaced digits keep values from shifting.
    static let numeric = Font.system(.body, design: .monospaced).monospacedDigit()
}
