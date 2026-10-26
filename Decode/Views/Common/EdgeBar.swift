import SwiftUI

extension View {
    /// Pins `bar` to the top or bottom edge over a progressive blur that runs
    /// from the screen edge through the bar and eases out just past it.
    func edgeBar<Bar: View>(_ edge: VerticalEdge, fade: CGFloat = 10, @ViewBuilder bar: () -> Bar) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            bar()
                .background {
                    VariableBlur(edge: edge, radius: 18)
                        .padding(edge == .top ? .bottom : .top, -fade)
                        .ignoresSafeArea()
                }
        }
    }

    /// Smoked glass behind a floating control. Pair with white content.
    func glassChrome<S: Shape>(in shape: S) -> some View {
        background { FrostedGlass(shape: shape, opacity: 0.86, blur: 20, glow: 70, shadowRadius: 12) }
    }
}

/// Smoked glass: near-black with a soft light pooling in the top-leading
/// corner, a thin rim that catches that light, and a deep diffuse shadow.
/// A little of the blurred backdrop bleeds through, so it reads as glass
/// rather than paint.
struct FrostedGlass<S: Shape>: View {
    let shape: S
    /// How opaque the smoke is; lower lets more of the blurred backdrop through.
    var opacity = 0.88
    var blur: CGFloat = 36
    /// Reach of the corner light, in points.
    var glow: CGFloat = 260
    var shadowRadius: CGFloat = 26

    var body: some View {
        BackdropBlur(radius: blur)
            .clipShape(shape)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.2, blue: 0.21).opacity(opacity),
                            Color(red: 0.05, green: 0.05, blue: 0.06).opacity(min(1, opacity + 0.04)),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.fill(
                    RadialGradient(
                        colors: [.white.opacity(0.14), .white.opacity(0)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: glow
                    )
                )
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.26), location: 0),
                            .init(color: .white.opacity(0.03), location: 0.5),
                            .init(color: .white.opacity(0.1), location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .background {
                shape
                    .fill(Color.black.opacity(0.3))
                    .blur(radius: shadowRadius)
                    .offset(y: shadowRadius * 0.55)
            }
    }
}
