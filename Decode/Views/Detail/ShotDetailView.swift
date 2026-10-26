import SwiftUI
import UIKit

/// Full-size view of one image. "Re-decode" replays the binary sweep with larger
/// glyphs (the money shot for recordings); "Upscale" replays it with finer glyphs
/// and badges the result as 2×.
struct ShotDetailView: View {
    let route: ShotRoute

    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @State private var replayStart: Date?
    @State private var replayDensity: CGFloat = 1.35
    @State private var replayDuration = 3.2
    @State private var isUpscaled = false
    @State private var pendingUpscale = false
    @State private var savedCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                artwork

                if let author = route.author {
                    HStack(spacing: 8) {
                        Avatar(name: author, size: 26)
                        Text(verbatim: author)
                            .font(.label.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if let likes = route.likes {
                            Label(likes.compact, systemImage: "heart")
                                .font(.monoValue)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(route.title)
                        .font(.screenTitle)
                        .tracking(-0.7)
                        .foregroundStyle(Theme.ink)
                    Text(route.prompt)
                        .font(.prose)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .contextMenu {
                            Button("Copy prompt", systemImage: "doc.on.doc") {
                                studio.copyPrompt(route.prompt)
                            }
                        }
                }
                .padding(.horizontal, 4)

                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        MetaChip(systemImage: "cpu", text: route.model.slug)
                        MetaChip(systemImage: route.ratio.symbol, text: route.ratio.rawValue)
                        MetaChip(systemImage: route.style.symbol, text: route.style.rawValue.lowercased())
                        MetaChip(systemImage: "number", text: "\(route.seed * 7919 % 99_991)")
                        MetaChip(systemImage: "rectangle.dashed", text: isUpscaled ? "2× upscaled" : route.ratio.pixels)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .padding(.horizontal, -16)

                HStack(spacing: 8) {
                    Button {
                        play(density: 1.35, duration: 3.2)
                    } label: {
                        ActionLabel(title: "Re-decode", systemImage: "arrow.clockwise", isProminent: true)
                    }

                    Button {
                        pendingUpscale = true
                        play(density: 0.8, duration: 3.8)
                    } label: {
                        ActionLabel(title: isUpscaled ? "Upscaled" : "Upscale 2×", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(isUpscaled)
                }
                .disabled(replayStart != nil)

                HStack(spacing: 8) {
                    SmallAction(title: "Remix", systemImage: "arrow.triangle.branch") {
                        studio.remix(route)
                    }
                    SmallAction(title: "Vary", systemImage: "square.on.square") {
                        studio.vary(route)
                    }
                    ShareLink(
                        item: Image(route.imageName),
                        preview: SharePreview(route.title, image: Image(route.imageName))
                    ) {
                        SmallActionLabel(title: "Share", systemImage: "square.and.arrow.up")
                    }
                    SmallAction(title: savedCount > 0 ? "Saved" : "Save", systemImage: savedCount > 0 ? "checkmark" : "arrow.down.to.line") {
                        save()
                    }
                }
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    studio.toggleFavorite(route.imageName)
                } label: {
                    Image(systemName: studio.isFavorite(route.imageName) ? "heart.fill" : "heart")
                        .foregroundStyle(studio.isFavorite(route.imageName) ? Color.red : Theme.ink)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel("Favourite")
            }
        }
        .task(id: replayStart) {
            guard let started = replayStart else { return }
            try? await Task.sleep(for: .seconds(replayDuration + 0.1))
            guard replayStart == started else { return }
            replayStart = nil
            if pendingUpscale {
                pendingUpscale = false
                isUpscaled = true
                studio.show("Upscaled to 2×", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        }
        .onChange(of: studio.replayRequest) { _, _ in
            play(density: 1.35, duration: 3.2)
        }
        .sensoryFeedback(trigger: savedCount) { _, _ in
            haptics ? .success : nil
        }
    }

    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        return Color.clear
            .aspectRatio(route.ratio.value, contentMode: .fit)
            .overlay {
                DecodeOnce(
                    imageName: route.imageName,
                    start: replayStart ?? .distantPast,
                    duration: replayDuration,
                    seed: route.seed,
                    density: replayDensity,
                    style: route.style
                )
            }
            .clipShape(shape)
            .overlay(alignment: .bottomLeading) {
                if isUpscaled {
                    Text(verbatim: "2×")
                        .font(.monoBadge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: Capsule())
                        .padding(12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.4), value: isUpscaled)
            .cardShadow()
    }

    private func play(density: CGFloat, duration: Double) {
        replayDensity = density
        replayDuration = duration
        replayStart = .now
    }

    private func save() {
        guard let image = UIImage(named: route.imageName) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedCount += 1
        studio.show("Saved to Photos", systemImage: "arrow.down.circle.fill")
    }
}

private struct ActionLabel: View {
    let title: String
    let systemImage: String
    var isProminent = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.label.weight(.semibold))
            .foregroundStyle(isProminent ? Color.white : Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isProminent ? Theme.ink : Theme.card, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isProminent ? Color.clear : Theme.hairline, lineWidth: 1)
            }
    }
}

private struct SmallAction: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SmallActionLabel(title: title, systemImage: systemImage)
        }
    }
}

private struct SmallActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(height: 20)
            Text(title)
                .font(.note.weight(.medium))
        }
        .foregroundStyle(Theme.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}
