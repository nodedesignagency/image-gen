import SwiftUI
import UIKit

/// Full-size view of one result. "Re-decode" replays the binary sweep at a
/// larger glyph size, which is the money shot for screen recordings.
struct ShotDetailView: View {
    let route: ShotRoute

    @State private var replayStart: Date?
    @State private var savedCount = 0

    private let replayDuration = 3.2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                artwork

                VStack(alignment: .leading, spacing: 6) {
                    Text(route.title)
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(Theme.ink)
                    Text(route.prompt)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                actions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: replayStart) {
            guard let started = replayStart else { return }
            try? await Task.sleep(for: .seconds(replayDuration + 0.1))
            if replayStart == started {
                replayStart = nil
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        return Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                if let replayStart {
                    DecodingImage(
                        imageName: route.imageName,
                        start: replayStart,
                        duration: replayDuration,
                        seed: route.seed,
                        density: 1.35
                    )
                    .id(replayStart)
                } else {
                    Image(route.imageName)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(shape)
            .background(Theme.card, in: shape)
            .cardShadow()
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                replayStart = .now
            } label: {
                ActionLabel(title: "Re-decode", systemImage: "arrow.clockwise", isProminent: true)
            }
            .disabled(replayStart != nil)

            ShareLink(
                item: Image(route.imageName),
                preview: SharePreview(route.title, image: Image(route.imageName))
            ) {
                ActionLabel(title: "Share", systemImage: "square.and.arrow.up")
            }

            Button {
                save()
            } label: {
                ActionLabel(
                    title: savedCount > 0 ? "Saved" : "Save",
                    systemImage: savedCount > 0 ? "checkmark" : "arrow.down.to.line"
                )
            }
        }
        .buttonStyle(PressableStyle())
    }

    private func save() {
        guard let image = UIImage(named: route.imageName) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedCount += 1
    }
}

private struct ActionLabel: View {
    let title: String
    let systemImage: String
    var isProminent = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isProminent ? Color.white : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isProminent ? Theme.ink : Theme.card, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isProminent ? Color.clear : Theme.hairline, lineWidth: 1)
            }
    }
}
