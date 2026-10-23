import UIKit

/// The picture squashed down to one colour per glyph, so the bits in the band
/// already "look like" the image before the pixels arrive.
struct ImagePalette {
    let columns: Int
    let rows: Int
    private let colors: [RGB]

    func color(column: Int, row: Int) -> RGB {
        colors[row * columns + column]
    }

    static func make(from image: UIImage?, columns: Int, rows: Int) -> ImagePalette {
        let count = columns * rows
        let fallback = ImagePalette(columns: columns, rows: rows, colors: Array(repeating: RGB(r: 0.45, g: 0.45, b: 0.47), count: count))
        guard let cgImage = image?.cgImage else { return fallback }

        var pixels = [UInt8](repeating: 0, count: count * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: columns,
                height: rows,
                bitsPerComponent: 8,
                bytesPerRow: columns * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            let source = CGSize(width: cgImage.width, height: cgImage.height)
            context.draw(cgImage, in: aspectFill(source, into: CGSize(width: columns, height: rows)))
            return true
        }
        guard drawn else { return fallback }

        var colors: [RGB] = []
        colors.reserveCapacity(count)
        for index in 0..<count {
            var color = RGB(
                r: Double(pixels[index * 4]) / 255,
                g: Double(pixels[index * 4 + 1]) / 255,
                b: Double(pixels[index * 4 + 2]) / 255
            )
            // Keep pale tones readable on the light placeholder.
            let luma = 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
            if luma > 0.72 {
                let k = 0.72 / luma
                color = RGB(r: color.r * k, g: color.g * k, b: color.b * k)
            }
            colors.append(color)
        }
        return ImagePalette(columns: columns, rows: rows, colors: colors)
    }

    private static func aspectFill(_ source: CGSize, into target: CGSize) -> CGRect {
        let scale = max(target.width / source.width, target.height / source.height)
        let size = CGSize(width: source.width * scale, height: source.height * scale)
        return CGRect(
            x: (target.width - size.width) / 2,
            y: (target.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

/// Palettes are tiny but sampling decodes the JPEG, so keep them around.
final class PaletteCache {
    static let shared = PaletteCache()
    private var store: [String: ImagePalette] = [:]

    func palette(for name: String, columns: Int, rows: Int) -> ImagePalette {
        let key = "\(name)#\(columns)x\(rows)"
        if let hit = store[key] { return hit }
        let made = ImagePalette.make(from: UIImage(named: name), columns: columns, rows: rows)
        store[key] = made
        return made
    }
}
