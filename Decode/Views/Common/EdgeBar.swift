import SwiftUI

extension View {
    /// Pins `bar` to the top or bottom edge over a progressive blur that runs
    /// from the screen edge through the bar and eases out just past it.
    /// With `lite`, a plain canvas fade stands in for the blur (no backdrop sampling).
    func edgeBar<Bar: View>(_ edge: VerticalEdge, fade: CGFloat = 10, lite: Bool = false, @ViewBuilder bar: () -> Bar) -> some View {
        safeAreaInset(edge: edge, spacing: 0) {
            bar()
                .background {
                    if lite {
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

    /// Dark smoked glass: one standard material blur under a charcoal tint, a
    /// top-left glow and a light rim. Not the system's Liquid Glass: in the
    /// simulator that re-ran its refraction passes for every glass piece on
    /// every frame the canvas changed, which held a decode at 20 fps.
    /// `strength` is how dark the tint is. Pair with white content.
    /// `lite` paints a translucent dark fill instead, which costs nothing per frame.
    @ViewBuilder
    func smokedGlass<S: Shape>(in shape: S, strength: Double = 0.55, interactive: Bool = false, lite: Bool = false) -> some View {
        if lite {
            background {
                shape.fill(Color(white: 0.1).opacity(0.84))
                    .overlay { shape.stroke(.white.opacity(0.14), lineWidth: 1) }
            }
        } else {
            background { FrostedGlass(shape: shape, opacity: strength) }
        }
    }

    /// Smoked glass behind a tappable floating control. These sit on the
    /// header's progressive blur already, so they skip a backdrop blur of
    /// their own: the same tint, glow and rim over already-blurred content
    /// reads the same, and three fewer blurs re-render while scrolling.
    @ViewBuilder
    func glassChrome<S: Shape>(in shape: S, lite: Bool = false) -> some View {
        if lite {
            smokedGlass(in: shape, lite: true)
        } else {
            background { FrostedGlass(shape: shape, opacity: 0.6, blursBackdrop: false) }
        }
    }
}

/// Backdrop blur under translucent charcoal, a soft corner light and a rim
/// that catches it. The shadow comes from a still shape behind, so it isn't
/// re-rendered as the blurred backdrop changes.
struct FrostedGlass<S: Shape>: View {
    let shape: S
    var opacity = 0.55
    var blursBackdrop = true

    var body: some View {
        base
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
                shape.fill(Color.black.opacity(0.26)).blur(radius: 18).offset(y: 8)
            }
    }

    /// The material blur, or (for chrome that already sits on a blur) the
    /// material's dark tint alone.
    @ViewBuilder private var base: some View {
        if blursBackdrop {
            shape.fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        } else {
            shape.fill(Color.black.opacity(0.3))
        }
    }
}
