import CoreGraphics
import Foundation

/// The numbers behind the binary reveal, kept away from SwiftUI so they're easy to tune.
///
/// Positions are normalised: y = 0 is the top of the image, 1 the bottom.
/// Each column of glyphs has its own "head" (the decode front). Above the head minus
/// `band` the real pixels are fully visible; between tail and head glyphs are tinted
/// with the picture's colours; below the head is idle noise.
enum DecodeMath {
    /// Height of the tinted glyph band trailing the front.
    static let band = 0.30
    /// How far columns may lag behind each other, which gives the front its wave.
    static let jitter = 0.22
    /// Glyph grid pitch at density 1, in points.
    static let columnWidth: CGFloat = 7.6
    static let rowHeight: CGFloat = 10.5
    static let fontSize: CGFloat = 9

    static func hash(_ a: Int, _ b: Int, _ c: Int) -> UInt32 {
        var h = UInt32(truncatingIfNeeded: a) &* 0x8DA6_B343
        h ^= UInt32(truncatingIfNeeded: b) &* 0xD816_3841
        h ^= UInt32(truncatingIfNeeded: c) &* 0xCB1A_B31F
        h ^= h >> 15
        h &*= 0x2C1B_3C6D
        h ^= h >> 12
        h &*= 0x297A_2D39
        h ^= h >> 15
        return h
    }

    /// Stable pseudo-random value in 0...1.
    static func random(_ a: Int, _ b: Int, _ c: Int) -> Double {
        Double(hash(a, b, c)) / Double(UInt32.max)
    }

    /// Half smoothstep: starts and lands softly without stalling in the middle.
    static func ease(_ p: Double) -> Double {
        let s = p * p * (3 - 2 * p)
        return p + (s - p) * 0.5
    }

    /// 1D value noise, smooth across neighbouring columns.
    static func noise(_ x: Double, seed: Int) -> Double {
        let i = Int(x.rounded(.down))
        let f = x - Double(i)
        let u = f * f * (3 - 2 * f)
        return random(i, seed, 31) * (1 - u) + random(i + 1, seed, 31) * u
    }

    /// Normalised y of the decode front in `column` at `progress` (0...1).
    /// At 0 every head sits above the image; at 1 every tail has cleared the bottom.
    static func head(column: Int, progress: Double, seed: Int) -> Double {
        let lag = 0.72 * noise(Double(column) * 0.3, seed: seed) + 0.28 * random(column, seed, 13)
        return ease(progress) * (1 + band + jitter) - lag * jitter
    }
}

/// Glyph lattice for a given view size.
struct DecodeGrid: Equatable {
    let size: CGSize
    let columns: Int
    let rows: Int

    init(size: CGSize, density: CGFloat = 1) {
        self.size = size
        columns = max(1, Int(size.width / (DecodeMath.columnWidth * density)))
        rows = max(1, Int(size.height / (DecodeMath.rowHeight * density)))
    }

    var cellWidth: CGFloat { size.width / CGFloat(columns) }
    var cellHeight: CGFloat { size.height / CGFloat(rows) }
}
