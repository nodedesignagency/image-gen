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

    /// Frosted grey glass behind a floating control. Pair with white content.
    func glassChrome<S: Shape>(in shape: S) -> some View {
        background { FrostedGlass(shape: shape, tintOpacity: 0.34, blur: 16, sheen: 0.16) }
    }
}

/// Frosted glass: an even blur of whatever is behind, a grey tint, a soft top
/// sheen and a thin bright rim, with a diffuse drop shadow.
struct FrostedGlass<S: Shape>: View {
    let shape: S
    var tint = Color(white: 0.1)
    var tintOpacity = 0.5
    var blur: CGFloat = 26
    var sheen = 0.12

    var body: some View {
        BackdropBlur(radius: blur)
            .clipShape(shape)
            .overlay { shape.fill(tint.opacity(tintOpacity)) }
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(sheen), .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            }
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.32), .white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .background {
                shape
                    .fill(Color.black.opacity(0.16))
                    .blur(radius: 18)
                    .offset(y: 10)
            }
    }
}
