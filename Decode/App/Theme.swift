import SwiftUI

enum Theme {
    static let canvas = Color(red: 0.949, green: 0.949, blue: 0.941)
    static let card = Color.white
    static let placeholder = Color(red: 0.933, green: 0.933, blue: 0.925)
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.075)
    static let secondary = Color(red: 0.54, green: 0.54, blue: 0.56)
    static let hairline = Color.black.opacity(0.06)
    static let accent = Color(red: 0.176, green: 0.357, blue: 1.0)

    static let cardRadius: CGFloat = 22
    static let cellRadius: CGFloat = 14
    static let cardPadding: CGFloat = 8
}

/// Type pairing: SF for anything a person wrote or reads as prose, SF Mono
/// for machine values (counts, ratios, model ids, timers, bits).
extension Font {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Soft two-layer lift used for every white surface on the canvas.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.07), radius: 18, y: 10)
    }
}

/// Plain RGB triple so the decode renderer can blend colours cheaply per glyph.
struct RGB: Hashable {
    var r: Double
    var g: Double
    var b: Double

    static let ink = RGB(r: 0.067, g: 0.067, b: 0.075)
    static let accent = RGB(r: 0.176, g: 0.357, b: 1.0)

    func mixed(with other: RGB, _ t: Double) -> RGB {
        RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func color(opacity: Double) -> Color {
        Color(red: r, green: g, blue: b, opacity: opacity)
    }
}
