import Foundation

/// A post in the Explore feed. All canned: the same bundled photos, credited
/// to made-up creators.
struct FeedItem: Identifiable, Hashable {
    let id = UUID()
    let imageName: String
    let presetID: String
    let title: String
    let prompt: String
    let author: String
    let likes: Int
    let ratio: AspectRatio
    let seed: Int

    var route: ShotRoute {
        ShotRoute(
            id: id,
            imageName: imageName,
            title: title,
            prompt: prompt,
            seed: seed,
            ratio: ratio,
            style: .natural,
            author: author,
            likes: likes
        )
    }

    static let all: [FeedItem] = {
        let authors = ["mira.lab", "kofi.frames", "studio.ama", "lena.kz", "tomasz.render", "juno.wav", "hollow.form", "pixelmonk"]
        let ratios: [AspectRatio] = [.portrait, .square, .story, .portrait, .square, .portrait, .story]
        let flourishes = ["", ", shot on 35mm", ", wide angle, quiet mood", ", macro detail, shallow depth"]
        var items: [FeedItem] = []
        var index = 0
        // Interleave presets so the feed mixes themes.
        for variant in 1...4 {
            for preset in Preset.all {
                items.append(FeedItem(
                    imageName: "\(preset.id)-\(variant)",
                    presetID: preset.id,
                    title: preset.title,
                    prompt: preset.prompt + flourishes[variant - 1],
                    author: authors[index % authors.count],
                    likes: 140 + Int(DecodeMath.random(index, 7, 3) * 4800),
                    ratio: ratios[index % ratios.count],
                    seed: index * 31 + 7
                ))
                index += 1
            }
        }
        return items
    }()
}

enum FeedFilter: String, CaseIterable, Identifiable {
    case trending = "Trending"
    case new = "New"
    case architecture = "Architecture"
    case night = "Night"
    case ocean = "Ocean"
    case nature = "Nature"
    case stillLife = "Still life"

    var id: String { rawValue }

    func apply(to items: [FeedItem]) -> [FeedItem] {
        switch self {
        case .trending: return items.sorted { $0.likes > $1.likes }
        case .new: return Array(items.reversed())
        case .architecture: return items.filter { $0.presetID == "concrete" }
        case .night: return items.filter { $0.presetID == "afterdark" }
        case .ocean: return items.filter { $0.presetID == "deepblue" }
        case .nature: return items.filter { $0.presetID == "mist" || $0.presetID == "golden" }
        case .stillLife: return items.filter { $0.presetID == "stilllife" }
        }
    }
}

extension Int {
    /// 1840 -> "1.8k"
    var compact: String {
        self < 1000 ? "\(self)" : String(format: "%.1fk", Double(self) / 1000)
    }
}
