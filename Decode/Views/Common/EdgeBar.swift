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

    /// Dark-tinted glass. On iOS 26+ this is the system's Liquid Glass, which
    /// refracts whatever sits behind it; earlier versions get a painted stand-in.
    /// `strength` is how dark the tint is. Pair with white content.
    @ViewBuilder
    func smokedGlass<S: Shape>(in shape: S, strength: Double = 0.55, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(Color.black.opacity(strength)).interactive(interactive), in: shape)
        } else {
            background { FrostedGlass(shape: shape, opacity: strength + 0.15) }
        }
        #else
        background { FrostedGlass(shape: shape, opacity: strength + 0.15) }
        #endif
    }

    /// Smoked glass behind a tappable floating control.
    func glassChrome<S: Shape>(in shape: S) -> some View {
        smokedGlass(in: shape, strength: 0.6, interactive: true)
    }
}

/// Groups neighbouring glass views so the system renders them together
/// (Liquid Glass needs this when several pieces sit close to each other).
struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Painted stand-in for pre-iOS 26: backdrop blur under translucent charcoal,
/// a soft corner light and a rim that catches it.
struct FrostedGlass<S: Shape>: View {
    let shape: S
    var opacity = 0.7
    var blur: CGFloat = 30

    var body: some View {
        BackdropBlur(radius: blur)
            .clipShape(shape)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [Color(white: 0.2).opacity(opacity), Color(white: 0.05).opacity(opacity)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                shape.fill(
                    RadialGradient(colors: [.white.opacity(0.14), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
                )
            }
            .overlay {
                shape.stroke(
                    LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
            }
            .background {
                shape.fill(Color.black.opacity(0.28)).blur(radius: 20).offset(y: 10)
            }
    }
}
