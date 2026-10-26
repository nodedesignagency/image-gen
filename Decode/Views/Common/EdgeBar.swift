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

    /// Dark glass behind a floating control. Pair with white content.
    func glassChrome<S: Shape>(in shape: S) -> some View {
        background { FrostedGlass(shape: shape, opacity: 0.8, blur: 18) }
    }
}

/// Dark smoked glass: an even blur of whatever is behind under a charcoal
/// gradient (lighter top-leading, near black bottom-trailing), a faint top
/// sheen, a thin rim that catches light along the top, and a soft shadow.
struct FrostedGlass<S: Shape>: View {
    let shape: S
    /// How much of the charcoal covers the blur; lower lets more show through.
    var opacity = 0.84
    var blur: CGFloat = 30

    var body: some View {
        BackdropBlur(radius: blur)
            .clipShape(shape)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [Color(white: 0.24).opacity(opacity), Color(white: 0.05).opacity(opacity)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.09), location: 0),
                            .init(color: .white.opacity(0), location: 0.5),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.2), location: 0),
                            .init(color: .white.opacity(0.04), location: 0.4),
                            .init(color: .white.opacity(0.07), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .background {
                shape
                    .fill(Color.black.opacity(0.22))
                    .blur(radius: 20)
                    .offset(y: 12)
            }
    }
}
