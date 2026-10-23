import SwiftUI

/// A styled, aspect-filled bundled image.
struct StyledImage: View {
    let imageName: String
    var style: ImageStyle = .natural

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .imageStyle(style)
    }
}

/// Runs one decode sweep starting at `start`, then settles on a plain image so no
/// timeline keeps ticking. Pass a new `start` to play it again; `nil` shows the
/// empty placeholder.
struct DecodeOnce: View {
    let imageName: String
    let start: Date?
    var duration: Double = 2.4
    var seed: Int = 0
    var density: CGFloat = 1
    var style: ImageStyle = .natural

    @State private var finished: Date?

    var body: some View {
        if let start {
            if finished == start {
                StyledImage(imageName: imageName, style: style)
            } else {
                DecodingImage(imageName: imageName, start: start, duration: duration, seed: seed, density: density, style: style)
                    .task(id: start) {
                        let remaining = start.addingTimeInterval(duration + 0.05).timeIntervalSinceNow
                        if remaining > 0 {
                            try? await Task.sleep(for: .seconds(remaining))
                        }
                        if !Task.isCancelled {
                            finished = start
                        }
                    }
            }
        } else {
            Theme.placeholder
        }
    }
}

/// Decodes an image the first time it appears in this session (Explore feed,
/// paywall hero). Remembers per key, so scrolling back doesn't replay it.
struct RevealImage: View {
    let key: String
    let imageName: String
    var delay: Double = 0
    var duration: Double = 1.6
    var seed: Int = 0
    var style: ImageStyle = .natural

    var body: some View {
        if SettingsKey.revealsFeed {
            DecodeOnce(
                imageName: imageName,
                start: RevealMemory.shared.start(for: key, delay: delay),
                duration: duration,
                seed: seed,
                style: style
            )
        } else {
            StyledImage(imageName: imageName, style: style)
        }
    }
}

final class RevealMemory {
    static let shared = RevealMemory()
    private var starts: [String: Date] = [:]

    func start(for key: String, delay: Double) -> Date {
        if let known = starts[key] { return known }
        let start = Date.now.addingTimeInterval(delay)
        starts[key] = start
        return start
    }

    func forget() {
        starts = [:]
    }
}
