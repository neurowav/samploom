import SamploomDomain
import SwiftUI

/// Waveform of the loaded sample with the slice windows drawn on top.
struct WaveformView: View {
    let sample: DecodedSample
    let plan: SlicePlan?
    /// Start of the slice being heard, highlighted above the plan.
    let playingStart: TimeInterval?

    var body: some View {
        Canvas { context, size in
            drawWaveform(in: &context, size: size)
            drawPlan(in: &context, size: size)
            drawPlayingSlice(in: &context, size: size)
        }
        .frame(height: 96)
        .background(.backgroundPrimary, in: .rect(cornerRadius: Metrics.Radius.chip))
        .overlay {
            RoundedRectangle(cornerRadius: Metrics.Radius.chip)
                .strokeBorder(.hairline, lineWidth: Metrics.Stroke.hairline)
        }
        .accessibilityLabel("Waveform with \(plan?.starts.count ?? 0) slice starts")
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        guard !sample.waveform.isEmpty, size.width > 0 else { return }
        let barWidth: CGFloat = size.width / CGFloat(sample.waveform.count)
        for (index, peak) in sample.waveform.enumerated() {
            let height: CGFloat = max(1, CGFloat(peak) * size.height * 0.92)
            let rect: CGRect = .init(
                x: CGFloat(index) * barWidth,
                y: (size.height - height) / 2,
                width: max(1, barWidth * 0.9),
                height: height
            )
            context.fill(Path(rect), with: .color(.accent.opacity(0.55)))
        }
    }

    private func drawPlan(in context: inout GraphicsContext, size: CGSize) {
        guard let plan, sample.duration > 0, size.width > 0 else { return }
        let windowWidth: CGFloat = CGFloat(plan.sliceLength / sample.duration) * size.width
        for start in plan.starts {
            let x: CGFloat = CGFloat(start / sample.duration) * size.width
            let width: CGFloat = min(windowWidth, size.width - x)
            guard width > 0 else { continue }
            let rect: CGRect = .init(x: x, y: 0, width: width, height: size.height)
            context.fill(Path(rect), with: .color(.accent.opacity(0.16)))
            context.stroke(
                Path { path in
                    path.move(to: .init(x: x, y: 0))
                    path.addLine(to: .init(x: x, y: size.height))
                },
                with: .color(.accent),
                lineWidth: Metrics.Stroke.hairline
            )
        }
    }

    private func drawPlayingSlice(in context: inout GraphicsContext, size: CGSize) {
        guard let plan, let playingStart, sample.duration > 0, size.width > 0 else { return }
        let x: CGFloat = CGFloat(playingStart / sample.duration) * size.width
        let width: CGFloat = min(CGFloat(plan.sliceLength / sample.duration) * size.width, size.width - x)
        guard width > 0 else { return }
        let rect: CGRect = .init(x: x, y: 0, width: width, height: size.height)
        context.fill(Path(rect), with: .color(.accent.opacity(0.3)))
        context.stroke(
            Path(rect),
            with: .color(.accent),
            lineWidth: Metrics.Stroke.hairline * 2
        )
    }
}
