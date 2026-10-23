import SwiftUI

/// Reveals an image from the top down as a falling field of 0s and 1s.
///
/// Before `start` the cell idles as faint drifting bits. Once the sweep starts, a
/// wavy front travels down: right at the front the bits glow accent blue, behind it
/// they take on the picture's own colours, and further back the real pixels fade in.
/// At progress 1 the output is pixel-identical to a plain `Image`, so callers can
/// swap to one with no visible jump.
struct DecodingImage: View {
    let imageName: String
    let start: Date
    var duration: Double = 2.4
    var seed: Int = 0
    /// Larger than 1 means bigger, sparser glyphs (used on the full-screen view).
    var density: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let grid = DecodeGrid(size: proxy.size, density: density)
            let palette = PaletteCache.shared.palette(for: imageName, columns: grid.columns, rows: grid.rows)

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                let progress = min(max(elapsed / duration, 0), 1)

                ZStack {
                    Theme.placeholder

                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .mask {
                            RevealMask(grid: grid, progress: progress, seed: seed)
                        }

                    BitField(
                        grid: grid,
                        palette: palette,
                        progress: progress,
                        time: elapsed,
                        seed: seed,
                        density: density
                    )
                }
            }
        }
        .accessibilityLabel("Generating image")
    }
}

/// Alpha mask for the real pixels: opaque above each column's tail, fading out
/// toward its head.
private struct RevealMask: View {
    let grid: DecodeGrid
    let progress: Double
    let seed: Int

    var body: some View {
        Canvas { context, size in
            let band = DecodeMath.band
            let width = grid.cellWidth + 0.75 // overlap to avoid hairline seams
            for column in 0..<grid.columns {
                let head = DecodeMath.head(column: column, progress: progress, seed: seed)
                let x = CGFloat(column) * grid.cellWidth
                let solid = CGFloat(head - band) * size.height
                let fadeEnd = CGFloat(head - band * 0.15) * size.height

                if solid > 0 {
                    context.fill(Path(CGRect(x: x, y: 0, width: width, height: solid)), with: .color(.black))
                }
                if fadeEnd > 0, fadeEnd > solid {
                    context.fill(
                        Path(CGRect(x: x, y: solid, width: width, height: fadeEnd - solid)),
                        with: .linearGradient(
                            Gradient(colors: [.black, .black.opacity(0)]),
                            startPoint: CGPoint(x: x, y: solid),
                            endPoint: CGPoint(x: x, y: fadeEnd)
                        )
                    )
                }
            }
        }
    }
}

/// The glyphs themselves.
private struct BitField: View {
    let grid: DecodeGrid
    let palette: ImagePalette
    let progress: Double
    let time: Double
    let seed: Int
    let density: CGFloat

    var body: some View {
        Canvas { context, size in
            let font = Font.system(size: DecodeMath.fontSize * density, weight: .semibold, design: .monospaced)
            let zero = context.resolve(Text(verbatim: "0").font(font))
            let one = context.resolve(Text(verbatim: "1").font(font))

            let band = DecodeMath.band
            let rowStep = 1 / Double(grid.rows)

            for column in 0..<grid.columns {
                let head = DecodeMath.head(column: column, progress: progress, seed: seed)
                let x = (CGFloat(column) + 0.5) * grid.cellWidth

                // A brighter "drop" that keeps falling through the idle noise.
                let speed = 0.35 + 0.55 * DecodeMath.random(column, 3, seed)
                let cycle = time * speed + DecodeMath.random(column, 5, seed)
                let drop = (cycle - cycle.rounded(.down)) * 1.6 - 0.3

                for row in 0..<grid.rows {
                    let y = (Double(row) + 0.5) * rowStep
                    let distance = head - y
                    if distance > band { continue } // fully decoded, real pixels show

                    // Each glyph flips at its own rate; faster inside the band.
                    let rate = 6 + 14 * DecodeMath.random(column, row, 99)
                    let offset = DecodeMath.random(row, column, 4) * 10
                    let tick = Int((time * (distance >= 0 ? rate * 1.6 : rate) + offset).rounded(.down))
                    let isOne = DecodeMath.hash(column, row, tick) & 1 == 1

                    let tint: RGB
                    let opacity: Double
                    if distance >= 0 {
                        let k = distance / band
                        if distance < rowStep {
                            tint = .accent
                            opacity = 1
                        } else {
                            tint = palette.color(column: column, row: row).mixed(with: .accent, pow(1 - k, 3) * 0.55)
                            opacity = pow(1 - k, 0.7) * 0.95
                        }
                    } else {
                        let below = -distance
                        let trail = drop - y
                        let boost = trail > 0 && trail < 0.28 ? 1 - trail / 0.28 : 0
                        if below < 0.06 {
                            tint = .accent
                            opacity = max(0.07 + boost * 0.22, 0.55 * (1 - below / 0.06))
                        } else {
                            tint = .ink
                            opacity = 0.07 + boost * 0.22
                        }
                    }

                    var glyph = isOne ? one : zero
                    glyph.shading = .color(tint.color(opacity: opacity))
                    context.draw(glyph, at: CGPoint(x: x, y: CGFloat(y) * size.height), anchor: .center)
                }
            }
        }
    }
}
