import SwiftUI

extension View {
    /// Pins `bar` to the top or bottom edge with a progressive blur behind it:
    /// content scrolling underneath gets blurrier toward the edge instead of
    /// being washed out by a flat fade.
    ///
    /// iOS 26 uses the system's soft scroll-edge effect (the variable blur Apple
    /// uses under bars). Earlier versions fall back to `ProgressiveBlur`.
    @ViewBuilder
    func edgeBar<Bar: View>(_ edge: VerticalEdge, @ViewBuilder bar: () -> Bar) -> some View {
        let content = bar()
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
                .safeAreaBar(edge: edge, spacing: 0) { content }
                .scrollEdgeEffectStyle(.soft, for: edge == .top ? .top : .bottom)
        } else {
            safeAreaInset(edge: edge, spacing: 0) {
                content.background { ProgressiveBlur(edge: edge) }
            }
        }
        #else
        safeAreaInset(edge: edge, spacing: 0) {
            content.background { ProgressiveBlur(edge: edge) }
        }
        #endif
    }
}

/// Stacked material layers, each masked a little further from the edge, so the
/// blur compounds toward the edge and eases off into the content.
struct ProgressiveBlur: View {
    let edge: VerticalEdge
    var layers = 5

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
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
