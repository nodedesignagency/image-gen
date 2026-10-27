import SwiftUI

// Nothing in here samples what's behind it. Backdrop blurs (Liquid Glass,
// materials, the private variable blur) re-render on every frame that content
// moves beneath them, and in the simulator that alone held scrolling at
// ~10 fps and decoding at ~20. The looks below are painted instead.

extension View {
    /// Pins `bar` to the top or bottom edge over a fade into the canvas that
    /// runs from the screen edge through the bar and eases out just past it,
    /// so content slides softly underneath.
    func edgeBar<Bar: View>(_ edge: VerticalEdge, fade: CGFloat = 26, @ViewBuilder bar: () -> Bar) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            bar()
                .background {
                    LinearGradient(
                        stops: [
                            .init(color: Theme.canvas, location: 0),
                            .init(color: Theme.canvas.opacity(0.94), location: 0.4),
                            .init(color: Theme.canvas.opacity(0.7), location: 0.72),
                            .init(color: Theme.canvas.opacity(0), location: 1),
                        ],
                        startPoint: edge == .top ? .top : .bottom,
                        endPoint: edge == .top ? .bottom : .top
                    )
                    .padding(edge == .top ? .bottom : .top, -fade)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
        }
    }

    /// Dark smoked glass: a charcoal tint with a top-left glow and a light rim.
    /// `strength` is how dark the tint is. Pair with white content.
    /// `lite` is a flat fill (Profile → Reduce effects).
    @ViewBuilder
    func smokedGlass<S: Shape>(in shape: S, strength: Double = 0.62, lite: Bool = false) -> some View {
        if lite {
            background {
                shape.fill(Color(white: 0.1).opacity(0.88))
                    .overlay { shape.stroke(.white.opacity(0.14), lineWidth: 1) }
            }
        } else {
            background { SmokedTint(shape: shape, opacity: strength) }
        }
    }

    /// Smoked glass behind a tappable floating control.
    func glassChrome<S: Shape>(in shape: S, lite: Bool = false) -> some View {
        smokedGlass(in: shape, strength: 0.6, lite: lite)
    }
}

/// Translucent charcoal, a soft corner light and a rim that catches it, over a
/// shadow drawn from the still shape.
struct SmokedTint<S: Shape>: View {
    let shape: S
    var opacity = 0.62

    var body: some View {
        shape
            .fill(Color.black.opacity(0.34))
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [Color(white: 0.18).opacity(opacity), Color(white: 0.04).opacity(opacity)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.fill(
                    RadialGradient(colors: [.white.opacity(0.13), .clear], center: .topLeading, startRadius: 0, endRadius: 240)
                )
            }
            .overlay {
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            }
            .background {
                shape.fill(Color.black.opacity(0.22)).offset(y: 6).blur(radius: 14)
            }
    }
}
