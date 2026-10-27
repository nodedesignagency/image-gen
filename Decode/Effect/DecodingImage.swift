import SwiftUI

/// Reveals an image from the top down as a falling field of 0s and 1s.
///
/// Before `start` the cell idles as faint drifting bits. Once the sweep starts, a
/// wavy front travels down: right at the front the bits glow accent blue, behind it
/// they take on the picture's own colours, and further back the real pixels fade in.
/// At progress 1 the output is pixel-identical to a plain `Image`, so callers can
/// swap to one with no visible jump.
///
/// The photo is drawn plainly and never changes. Everything that moves is an
/// overlay on top of it: one Metal pass (`decodeOverlay` in `Shaders.metal`)
/// over an empty rectangle that paints the placeholder over the undecoded part
/// and the bits over that. Keeping the photo out of the shader matters: a
/// photo inside a shader effect is re-rendered into a new texture every frame,
/// which in the simulator happens on the main thread and was most of the lag.
struct DecodingImage: View {
    let imageName: String
    let start: Date
    var duration: Double = 2.4
    var seed: Int = 0
    /// Larger than 1 means bigger, sparser glyphs (used on the full-screen view).
    var density: CGFloat = 1
    var style: ImageStyle = .natural

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let columns = max(1, Int(size.width / (7.6 * density)))
            let rows = max(1, Int(size.height / (10.5 * density)))

            ZStack {
                StyledImage(imageName: imageName, style: style)
                    .frame(width: size.width, height: size.height)
                    .clipped()

                // 30 fps is plenty for flickering bits and keeps four cells cheap.
                TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    let progress = min(max(elapsed / duration, 0), 1)
                    // The picture's colour per glyph, built off the main thread on
                    // first use; until then the band uses a neutral grey.
                    // ([-1] rather than empty: a zero-length buffer isn't allowed.)
                    let palette = PaletteCache.shared.cached(for: imageName, columns: columns, rows: rows)?.floats ?? [-1]

                    Rectangle()
                        .colorEffect(
                            ShaderLibrary.decodeOverlay(
                                .float2(size),
                                .float2(CGFloat(columns), CGFloat(rows)),
                                .float(progress),
                                .float(elapsed),
                                .float(Double(seed)),
                                .float(density),
                                .floatArray(palette)
                            )
                        )
                }
            }
        }
        .accessibilityLabel("Generating image")
    }
}
