import SwiftUI

extension View {
    /// Pins `bar` to the top or bottom edge over a progressive blur that runs
    /// from the screen edge through the bar and eases out just past it.
    /// With `lite`, a plain canvas fade stands in for the blur (no backdrop sampling).
    func edgeBar<Bar: View>(_ edge: VerticalEdge, fade: CGFloat = 10, lite: Bool = false, @ViewBuilder bar: () -> Bar) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            bar()
                .background {
                    if lite || UserDefaults.standard.bool(forKey: "perfNoBlur") {
                        LinearGradient(
                            colors: [Theme.canvas, Theme.canvas, Theme.canvas.opacity(0)],
                            startPoint: edge == .top ? .top : .bottom,
                            endPoint: edge == .top ? .bottom : .top
                        )
                        .padding(edge == .top ? .bottom : .top, -fade * 3)
                        .ignoresSafeArea()
                    } else {
                        VariableBlur(edge: edge, radius: 18)
                            .padding(edge == .top ? .bottom : .top, -fade)
                            .ignoresSafeArea()
                    }
                }
        }
    }

    /// Dark-tinted glass. On iOS 26+ this is the system's Liquid Glass, which
    /// refracts whatever sits behind it; earlier versions get a painted stand-in.
    /// `strength` is how dark the tint is. Pair with white content.
    /// `lite` paints a translucent dark fill instead, which costs nothing per frame.
    @ViewBuilder
    func smokedGlass<S: Shape>(in shape: S, strength: Double = 0.55, interactive: Bool = false, lite: Bool = false) -> some View {
        #if compiler(>=6.2)
        if lite || UserDefaults.standard.bool(forKey: "perfNoGlass") {
            background {
                shape.fill(Color(white: 0.1).opacity(0.84))
                    .overlay { shape.stroke(.white.opacity(0.14), lineWidth: 1) }
            }
        } else if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(Color.black.opacity(strength)).interactive(interactive), in: shape)
        } else {
            background { FrostedGlass(shape: shape, opacity: strength + 0.15) }
        }
        #else
        background { FrostedGlass(shape: shape, opacity: strength + 0.15) }
        #endif
    }

    /// Smoked glass behind a tappable floating control.
    func glassChrome<S: Shape>(in shape: S, lite: Bool = false) -> some View {
        smokedGlass(in: shape, strength: 0.6, interactive: true, lite: lite)
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
