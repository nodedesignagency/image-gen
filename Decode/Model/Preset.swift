import Foundation

/// A canned "generation". The app is a front-end demo: whatever you type,
/// one of these image sets gets decoded onto the canvas.
///
/// To use your own pictures, drop them into Assets.xcassets/Photos named
/// `<id>-1` … `<id>-4` (3:4 portrait works best) and edit the list below.
struct Preset: Identifiable, Hashable {
    let id: String
    let title: String
    let prompt: String
    let keywords: [String]

    var images: [String] { (1...4).map { "\(id)-\($0)" } }

    func score(_ text: String) -> Int {
        keywords.filter { text.contains($0) }.count
    }

    static let moodboard = (1...4).map { "ref-\($0)" }

    static let all: [Preset] = [
        Preset(
            id: "concrete",
            title: "Concrete Sky",
            prompt: "Towers shot from the street looking straight up, hard geometry against a pale sky",
            keywords: ["tower", "building", "architect", "city", "concrete", "brutal", "skyscraper", "geometr"]
        ),
        Preset(
            id: "afterdark",
            title: "After Dark",
            prompt: "Long-exposure night skies, aurora, star trails and the milky way over silent land",
            keywords: ["night", "star", "aurora", "galaxy", "milky", "space", "dark", "cosmic"]
        ),
        Preset(
            id: "golden",
            title: "Golden Hour",
            prompt: "Warm haze at golden hour, sun flare cutting through, soft film grain",
            keywords: ["sun", "golden", "warm", "sunset", "sunrise", "haze", "orange", "glow"]
        ),
        Preset(
            id: "deepblue",
            title: "Deep Blue",
            prompt: "Ocean blues from below and above, glowing jellyfish and glassy rolling waves",
            keywords: ["ocean", "sea", "water", "wave", "blue", "jelly", "underwater", "fish"]
        ),
        Preset(
            id: "stilllife",
            title: "Still Life",
            prompt: "Saturated fruit still life, macro detail, hard studio light",
            keywords: ["fruit", "food", "still", "berr", "strawberr", "coffee", "macro", "product"]
        ),
        Preset(
            id: "mist",
            title: "Mist",
            prompt: "Layered mountain ridges dissolving into morning fog, muted palette",
            keywords: ["mountain", "fog", "mist", "forest", "hill", "calm", "moody", "landscape"]
        ),
    ]
}
