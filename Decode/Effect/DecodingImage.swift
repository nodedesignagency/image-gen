import SwiftUI

/// Reveals an image from the top down as a falling field of 0s and 1s.
///
/// Before `start` the cell idles as faint drifting bits. Once the sweep starts, a
/// wavy front travels down: right at the front the bits glow accent blue, behind it
/// they take on the picture's own colours, and further back the real pixels fade in.
/// At progress 1 the output is pixel-identical to a plain `Image`, so callers can
/// swap to one with no visible jump.
///
/// The whole effect is one Metal pass over the finished image (`decodeReveal` in
/// `Shaders.metal`): the timeline only feeds it a clock, so a screen full of
/// decoding cells costs the CPU nothing per frame.
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
            // 30 fps is plenty for flickering bits and keeps four cells cheap.
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                let progress = min(max(elapsed / duration, 0), 1)

                StyledImage(imageName: imageName, style: style)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .layerEffect(
                        ShaderLibrary.decodeReveal(
                            .float2(proxy.size),
                            .float(progress),
                            .float(elapsed),
                            .float(Double(seed)),
                            .float(density)
                        ),
                        maxSampleOffset: .zero
                    )
            }
        }
        .accessibilityLabel("Generating image")
    }
}
