import SwiftUI

extension View {
    /// Pins `bar` to the top or bottom edge over a progressive blur that runs
    /// from the screen edge, through the bar, and `fade` points into the content.
    func edgeBar<Bar: View>(_ edge: VerticalEdge, fade: CGFloat = 44, @ViewBuilder bar: () -> Bar) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            bar()
                .background {
                    VariableBlur(edge: edge, radius: 22)
                        .padding(edge == .top ? .bottom : .top, -fade)
                        .ignoresSafeArea()
                }
        }
    }

    /// Glass surface for floating controls: Liquid Glass on iOS 26+, frosted
    /// material with a hairline before that.
    @ViewBuilder
    func glassChrome<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            materialChrome(in: shape)
        }
        #else
        materialChrome(in: shape)
        #endif
    }

    private func materialChrome<S: Shape>(in shape: S) -> some View {
        background(.ultraThinMaterial, in: shape)
            .overlay { shape.stroke(Color.white.opacity(0.7), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

/// Dark frosted panel used by the composer: blurred content shows through,
/// with a soft top highlight on the rim.
struct DarkGlass<S: Shape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .overlay { shape.fill(Color.black.opacity(0.42)) }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
    }
}
