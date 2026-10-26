import SwiftUI

/// Soft drifting colour behind the canvas edges, sampled from the latest
/// generation, so the glass above it has something to refract.
struct AmbientWash: View {
    let images: [String]
    var edge: VerticalEdge = .bottom
    var opacity = 0.5

    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                ForEach(Array(images.prefix(4).enumerated()), id: \.element) { index, name in
                    let palette = PaletteCache.shared.palette(for: name, columns: 2, rows: 2)
                    let colors = [
                        palette.color(column: 0, row: 0), palette.color(column: 1, row: 0),
                        palette.color(column: 1, row: 1), palette.color(column: 0, row: 1),
                    ].map { $0.color(opacity: 1) }
                    let seed = Double(index)

                    Ellipse()
                        .fill(AngularGradient(colors: colors + [colors[0]], center: .center))
                        .frame(width: width * 0.8, height: height * 0.95)
                        .blur(radius: 64)
                        .offset(
                            x: (seed - 1.5) * width * 0.24 + (drift ? cos(seed * 1.9) : sin(seed * 2.3)) * width * 0.2,
                            y: (drift ? sin(seed * 1.3) : cos(seed * 0.7)) * height * 0.2
                        )
                }
            }
            .saturation(1.6)
            .opacity(opacity)
            .frame(width: width, height: height)
            .mask {
                LinearGradient(
                    colors: edge == .bottom ? [.clear, .black] : [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .animation(.smooth(duration: 1.8), value: images)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
