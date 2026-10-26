import SwiftUI

enum AppTab: Hashable {
    case explore, create, library, profile
}

enum AspectRatio: String, CaseIterable, Identifiable, Hashable {
    case portrait = "3:4"
    case square = "1:1"
    case story = "9:16"

    var id: String { rawValue }

    /// width / height
    var value: CGFloat {
        switch self {
        case .portrait: 3.0 / 4.0
        case .square: 1
        case .story: 9.0 / 16.0
        }
    }

    var symbol: String {
        switch self {
        case .portrait: "rectangle.portrait"
        case .square: "square"
        case .story: "iphone"
        }
    }

    /// Fake output size shown in metadata.
    var pixels: String {
        switch self {
        case .portrait: "1536 × 2048"
        case .square: "2048 × 2048"
        case .story: "1152 × 2048"
        }
    }
}

/// A look applied on top of the bundled photos, so the style picker visibly does something.
enum ImageStyle: String, CaseIterable, Identifiable, Hashable {
    case natural = "Natural"
    case cinematic = "Cinematic"
    case mono = "Mono"
    case faded = "Faded"
    case warm = "Warm"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .natural: "circle.lefthalf.filled"
        case .cinematic: "film"
        case .mono: "circle.righthalf.filled"
        case .faded: "cloud.fog"
        case .warm: "sun.max"
        }
    }
}

extension View {
    @ViewBuilder
    func imageStyle(_ style: ImageStyle) -> some View {
        switch style {
        case .natural:
            self
        case .cinematic:
            self.contrast(1.12).saturation(1.15)
        case .mono:
            self.grayscale(1).contrast(1.15)
        case .faded:
            self.saturation(0.7).contrast(0.88).brightness(0.04)
        case .warm:
            self.colorMultiply(Color(red: 1, green: 0.93, blue: 0.82)).saturation(1.1)
        }
    }
}

/// Pretend model picker. Cost is credits per image.
enum GenModel: String, CaseIterable, Identifiable {
    case standard = "Decode 2"
    case pro = "Decode 2 Pro"
    case lite = "Decode Lite"

    var id: String { rawValue }

    /// Lower-case id used wherever metadata is shown in mono.
    var slug: String {
        switch self {
        case .standard: "decode-2"
        case .pro: "decode-2-pro"
        case .lite: "decode-lite"
        }
    }

    var detail: String {
        switch self {
        case .standard: "Balanced"
        case .pro: "Highest fidelity · 2 credits"
        case .lite: "Fastest"
        }
    }

    var cost: Int { self == .pro ? 2 : 1 }
}

enum DecodeSpeed: String, CaseIterable, Identifiable {
    case relaxed = "Relaxed"
    case normal = "Normal"
    case fast = "Fast"

    var id: String { rawValue }

    /// Scales every decode duration and stagger.
    var multiplier: Double {
        switch self {
        case .relaxed: 1.4
        case .normal: 1
        case .fast: 0.65
        }
    }
}

/// UserDefaults keys shared by `@AppStorage` in views and plain reads in the model.
enum SettingsKey {
    static let haptics = "haptics"
    static let decodeSpeed = "decodeSpeed"
    static let revealFeed = "revealFeed"
    static let hasOnboarded = "hasOnboarded"
    static let autopilot = "autopilot"
    static let edgeLens = "edgeLens"
    static let reduceEffects = "reduceEffects"

    static var speed: DecodeSpeed {
        DecodeSpeed(rawValue: UserDefaults.standard.string(forKey: decodeSpeed) ?? "") ?? .normal
    }

    static var revealsFeed: Bool {
        UserDefaults.standard.object(forKey: revealFeed) as? Bool ?? true
    }

    static var edgeLensEnabled: Bool {
        UserDefaults.standard.object(forKey: edgeLens) as? Bool ?? true
    }
}

/// Everything the detail screen needs about one image.
struct ShotRoute: Hashable {
    let id: UUID
    let imageName: String
    let title: String
    let prompt: String
    let seed: Int
    var ratio: AspectRatio = .portrait
    var style: ImageStyle = .natural
    var model: GenModel = .standard
    var author: String? = nil
    var likes: Int? = nil
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let systemImage: String
}
