import SwiftUI

/// Soft drifting lights behind the canvas, one per image of the latest
/// generation, so the glass above has something to refract. Four pool at
/// the bottom under the composer, two echo faintly under the header.
///
/// Fills the whole screen and fades its own edges, so nothing gets clipped.
struct AmbientWash: View {
    let images: [String]
    var opacity = 0.5

    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let lights = Self.lights(for: images)

            ZStack {
                ForEach(Array(lights.enumerated()), id: \.offset) { index, light in
                    let seed = Double(index)
                    let isTop = index >= 4
                    let slot = isTop ? index - 4 : index
                    let xs: [CGFloat] = isTop ? [0.3, 0.72] : [0.18, 0.5, 0.84, 0.5]
                    let ys: [CGFloat] = isTop ? [0.0, 0.02] : [0.9, 0.84, 0.94, 1.04]

                    Ellipse()
                        .fill(RadialGradient(colors: [light, light.opacity(0)], center: .center, startRadius: 0, endRadius: width * 0.42))
                        .frame(width: width * 0.9, height: width * 0.7)
                        .blur(radius: 36)
                        .opacity(isTop ? 0.5 : 1)
                        .position(
                            x: xs[slot] * width + (drift ? cos(seed * 1.9) : sin(seed * 2.3)) * width * 0.12,
                            y: ys[slot] * height + (drift ? sin(seed * 1.3) : cos(seed * 0.7)) * 36
                        )
                }
            }
            .opacity(opacity)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .clear, location: 0.2),
                        .init(color: .clear, location: 0.55),
                        .init(color: .black, location: 0.85),
                    ],
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

    /// One vivid light per image: its most saturated palette colour, pushed to a
    /// bright, saturated version so dark or grey photos don't produce mud. Nearly
    /// neutral photos fall back to a fixed hue. Returns four bottom lights, then
    /// two header echoes of the first pair.
    static func lights(for images: [String]) -> [Color] {
        let fallbackHues = [0.62, 0.85, 0.47, 0.08]
        var lights: [Color] = []
        for (index, name) in images.prefix(4).enumerated() {
            let palette = PaletteCache.shared.palette(for: name, columns: 3, rows: 3)
            var best = (hue: fallbackHues[index], saturation: 0.0)
            for column in 0..<3 {
                for row in 0..<3 {
                    let hsb = hsb(palette.color(column: column, row: row))
                    if hsb.saturation > best.saturation {
                        best = (hsb.hue, hsb.saturation)
                    }
                }
            }
            let hue = best.saturation < 0.14 ? fallbackHues[index] : best.hue
            lights.append(Color(hue: hue, saturation: 0.72, brightness: 0.96))
        }
        while lights.count < 4 {
            lights.append(Color(hue: fallbackHues[lights.count], saturation: 0.72, brightness: 0.96))
        }
        return lights + [lights[0], lights[1]]
    }

    private static func hsb(_ color: RGB) -> (hue: Double, saturation: Double) {
        let high = max(color.r, color.g, color.b)
        let low = min(color.r, color.g, color.b)
        let delta = high - low
        guard delta > 0.0001 else { return (0, 0) }
        var hue: Double
        if high == color.r {
            hue = ((color.g - color.b) / delta).truncatingRemainder(dividingBy: 6)
        } else if high == color.g {
            hue = (color.b - color.r) / delta + 2
        } else {
            hue = (color.r - color.g) / delta + 4
        }
        hue /= 6
        if hue < 0 { hue += 1 }
        return (hue, high == 0 ? 0 : delta / high)
    }
}
