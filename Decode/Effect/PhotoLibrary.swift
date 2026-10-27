import SwiftUI
import UIKit

/// The bundled photos, decoded once into display-ready bitmaps.
///
/// `Image("name")` hands SwiftUI a lazily decoded JPEG. Profiling showed
/// SwiftUI decoding those JPEGs again on the main thread every time it
/// re-rendered a photo into a texture, which during a decode or a scroll was
/// every frame, and that was most of the app's lag. These images are decoded
/// up front (`preparingForDisplay`), so drawing one is only ever a texture
/// lookup. Small copies serve the chips and thumbnails.
@MainActor
final class PhotoLibrary {
    static let shared = PhotoLibrary()

    private var full: [String: UIImage] = [:]
    private var thumbs: [String: UIImage] = [:]
    private var warming: Set<String> = []

    /// The decoded photo. Decodes on first use if `warm` hasn't run for it.
    func image(_ name: String) -> UIImage? {
        if let hit = full[name] { return hit }
        guard let raw = UIImage(named: name) else { return nil }
        let ready = raw.preparingForDisplay() ?? raw
        full[name] = ready
        return ready
    }

    /// A small decoded copy (longest side `Self.thumbSize` px) for chips.
    func thumbnail(_ name: String) -> UIImage? {
        if let hit = thumbs[name] { return hit }
        guard let raw = UIImage(named: name) else { return nil }
        let side = Self.thumbSize
        let size = raw.size.width > raw.size.height
            ? CGSize(width: side, height: side * raw.size.height / raw.size.width)
            : CGSize(width: side * raw.size.width / raw.size.height, height: side)
        let small = raw.preparingThumbnail(of: size) ?? raw
        thumbs[name] = small
        return small
    }

    /// Decodes `names` off the main thread so their first frame doesn't pay.
    func warm(_ names: [String]) {
        let todo = names.filter { full[$0] == nil && !warming.contains($0) }
        guard !todo.isEmpty else { return }
        warming.formUnion(todo)
        Task.detached(priority: .userInitiated) {
            var decoded: [(String, UIImage)] = []
            for name in todo {
                if let raw = UIImage(named: name) {
                    decoded.append((name, raw.preparingForDisplay() ?? raw))
                }
            }
            let ready = decoded
            await MainActor.run {
                for (name, image) in ready where PhotoLibrary.shared.full[name] == nil {
                    PhotoLibrary.shared.full[name] = image
                }
                PhotoLibrary.shared.warming.subtract(todo)
            }
        }
    }

    private static let thumbSize: CGFloat = 96
}

/// A bundled photo from `PhotoLibrary`, as a SwiftUI image.
@MainActor
func photo(_ name: String) -> Image {
    if let image = PhotoLibrary.shared.image(name) {
        return Image(uiImage: image)
    }
    return Image(name)
}

/// A small copy of a bundled photo, for chips and thumbnails.
@MainActor
func photoThumbnail(_ name: String) -> Image {
    if let image = PhotoLibrary.shared.thumbnail(name) {
        return Image(uiImage: image)
    }
    return Image(name)
}
