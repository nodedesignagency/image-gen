import SwiftUI
import UIKit

/// Progressive blur: strongest at `edge`, easing to nothing across the view.
///
/// Uses Core Animation's private "variableBlur" filter, the same one behind the
/// system's own scroll-edge blur, for a true variable radius with no white haze.
/// That's fine for this demo but is private API, so it isn't App Store-safe. If
/// the filter can't be created it falls back to stacked materials.
struct VariableBlur: View {
    var edge: VerticalEdge = .top
    var radius: CGFloat = 20

    var body: some View {
        Group {
            if VariableBlurView.isAvailable {
                VariableBlurRepresentable(edge: edge, radius: radius)
            } else {
                MaterialRamp(edge: edge)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Even, untinted blur of whatever is behind: the base of `FrostedGlass`.
struct BackdropBlur: View {
    var radius: CGFloat = 24

    var body: some View {
        Group {
            if VariableBlurView.isAvailable {
                VariableBlurRepresentable(edge: .top, radius: radius, uniform: true)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct VariableBlurRepresentable: UIViewRepresentable {
    let edge: VerticalEdge
    let radius: CGFloat
    var uniform = false

    func makeUIView(context: Context) -> VariableBlurView {
        VariableBlurView(edge: edge, radius: radius, uniform: uniform)
    }

    func updateUIView(_ view: VariableBlurView, context: Context) {}
}

final class VariableBlurView: UIVisualEffectView {
    static let isAvailable = makeFilter() != nil
    private var filter: NSObject?

    init(edge: VerticalEdge, radius: CGFloat, uniform: Bool = false) {
        super.init(effect: UIBlurEffect(style: .regular))
        isUserInteractionEnabled = false
        guard let filter = Self.makeFilter(), let mask = Self.mask(edge: edge, uniform: uniform) else { return }
        filter.setValue(radius, forKey: "inputRadius")
        filter.setValue(mask, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        self.filter = filter
        applyFilter()
    }

    /// The first subview hosts the backdrop; the rest add the material's tint.
    /// UIVisualEffectView re-installs its own filters (blur + a saturation
    /// boost) whenever it lays out, which made colour behind the bar pop
    /// against the unboosted canvas below it, so put ours back every time.
    private func applyFilter() {
        guard let filter, let backdrop = subviews.first?.layer else { return }
        if backdrop.filters?.count != 1 || (backdrop.filters?.first as? NSObject) !== filter {
            backdrop.filters = [filter]
        }
        for view in subviews.dropFirst() where view.alpha != 0 {
            view.alpha = 0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyFilter()
    }

    // The superclass rebuilds its effect here, which would drop our filter
    // (and can crash with a private one), so swallow the change.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {}

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Without this the unblurred end looks pixelated.
        guard let window, let backdrop = subviews.first?.layer else { return }
        backdrop.setValue(window.traitCollection.displayScale, forKey: "scale")
    }

    private static func makeFilter() -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        return filterClass.perform(NSSelectorFromString("filterWithType:"), with: "variableBlur")?
            .takeUnretainedValue() as? NSObject
    }

    /// Opaque (full blur) at the edge, clear (no blur) at the far side, or
    /// opaque throughout for an even blur.
    private static func mask(edge: VerticalEdge, uniform: Bool) -> CGImage? {
        let size = CGSize(width: 100, height: 100)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            if uniform {
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                return
            }
            let colors = [UIColor.black.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1]) else { return }
            let top = CGPoint(x: 0, y: 0)
            let bottom = CGPoint(x: 0, y: size.height)
            context.cgContext.drawLinearGradient(
                gradient,
                start: edge == .top ? top : bottom,
                end: edge == .top ? bottom : top,
                options: []
            )
        }
        return image.cgImage
    }
}

/// Fallback: material layers masked progressively further from the edge, so the
/// blur compounds toward it.
private struct MaterialRamp: View {
    let edge: VerticalEdge
    var layers = 6

    var body: some View {
        ZStack {
            ForEach(0..<layers, id: \.self) { index in
                let step = Double(index) / Double(layers)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: step * 0.55),
                                .init(color: .clear, location: 0.45 + step * 0.55),
                            ],
                            startPoint: edge == .top ? .top : .bottom,
                            endPoint: edge == .top ? .bottom : .top
                        )
                    }
            }
        }
    }
}
