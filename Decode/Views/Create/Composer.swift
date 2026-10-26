import SwiftUI

/// Bottom prompt panel in smoked glass: a roomy prompt on top, then a row of
/// round icon buttons and mono pills (model, style) that scrolls if it must,
/// and a light send button pinned right. Suggestions float above it.
/// Output is always 1:1 so the 2×2 fits above the panel in recordings.
struct Composer: View {
    @Environment(Studio.self) private var studio
    @FocusState private var isFocused: Bool
    @AppStorage(SettingsKey.reduceEffects) private var reduceEffects = false

    /// Bottom corners follow the screen's curve when the panel sits ~10pt from the edge.
    private let panel = UnevenRoundedRectangle(
        cornerRadii: RectangleCornerRadii(topLeading: 30, bottomLeading: 44, bottomTrailing: 44, topTrailing: 30),
        style: .continuous
    )

    var body: some View {
        @Bindable var studio = studio
        let hasText = !studio.prompt.trimmingCharacters(in: .whitespaces).isEmpty

        GlassGroup {
            VStack(spacing: 10) {
                // Suggestions step aside while a board decodes, giving it more room.
                if !studio.isGenerating {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(studio.presets) { preset in
                                Button {
                                    studio.prompt = preset.prompt
                                } label: {
                                    SuggestionChip(preset: preset, isSelected: studio.prompt == preset.prompt)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                VStack(alignment: .leading, spacing: 18) {
                    TextField(
                        "Imagine something",
                        text: $studio.prompt,
                        prompt: Text("Imagine something…").foregroundColor(.white.opacity(0.45)),
                        axis: .vertical
                    )
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.95))
                    .tint(.white)
                    .lineLimit(2...4)
                    .focused($isFocused)
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                RoundIconButton(isOn: studio.usesMoodboard, label: studio.usesMoodboard ? "Moodboard on" : "Moodboard off") {
                                    studio.toggleMoodboard()
                                } content: {
                                    MoodboardThumbs(isOn: studio.usesMoodboard)
                                }

                                RoundIconButton(isOn: studio.isEnhancing, label: "Enhance prompt") {
                                    studio.enhance()
                                } content: {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white.opacity(hasText || studio.isEnhancing ? 0.9 : 0.5))
                                        .symbolEffect(.pulse, isActive: studio.isEnhancing)
                                }

                                Menu {
                                    Picker("Model", selection: $studio.model) {
                                        ForEach(GenModel.allCases) { model in
                                            Text(model.rawValue).tag(model)
                                        }
                                    }
                                } label: {
                                    MonoPill(systemImage: "cpu", text: studio.model.slug)
                                }
                                .accessibilityLabel("Model: \(studio.model.rawValue)")

                                Menu {
                                    Picker("Style", selection: $studio.style) {
                                        ForEach(ImageStyle.allCases) { style in
                                            Label(style.rawValue, systemImage: style.symbol).tag(style)
                                        }
                                    }
                                } label: {
                                    MonoPill(systemImage: studio.style.symbol, text: studio.style.rawValue.lowercased())
                                }
                                .accessibilityLabel("Style: \(studio.style.rawValue)")
                            }
                            .padding(.leading, 14)
                            .padding(.trailing, 18)
                        }
                        .scrollIndicators(.hidden)
                        // Fade out before the send button instead of running under it.
                        .mask {
                            HStack(spacing: 0) {
                                Rectangle()
                                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 22)
                            }
                        }

                        SendButton(isBusy: studio.isGenerating) {
                            isFocused = false
                            studio.generate()
                        }
                        .padding(.trailing, 14)
                    }
                    .padding(.bottom, 16)
                }
                .smokedGlass(in: panel, strength: 0.62, lite: reduceEffects)
                .padding(.horizontal, 10)
        }
        }
        .animation(.smooth(duration: 0.35), value: studio.isGenerating)
    }
}

/// Small smoked-glass capsule used for suggestions above the panel.
private struct SuggestionChip: View {
    let preset: Preset
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(preset.images[0])
                .resizable()
                .scaledToFill()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
            Text(preset.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(Color(white: 0.12).opacity(0.78), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
        .overlay {
            if isSelected {
                Capsule().stroke(.white.opacity(0.85), lineWidth: 1.5)
            }
        }
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}

/// Outlined capsule with a mono value and a chevron, for pickers.
private struct MonoPill: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
            Text(verbatim: text)
                .font(.mono(13))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .opacity(0.7)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.white.opacity(0.04), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 1) }
        .contentShape(Capsule())
    }
}

/// 44pt round button with a faint fill and hairline, brighter when on.
private struct RoundIconButton<Content: View>: View {
    let isOn: Bool
    let label: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 44, height: 44)
                .background(.white.opacity(isOn ? 0.13 : 0.07), in: Circle())
                .overlay { Circle().stroke(.white.opacity(isOn ? 0.24 : 0.1), lineWidth: 1) }
                .contentShape(Circle())
                .animation(.smooth(duration: 0.2), value: isOn)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }
}

/// 2×2 of the moodboard references, greyed out when unlinked.
private struct MoodboardThumbs: View {
    let isOn: Bool

    var body: some View {
        Grid(horizontalSpacing: 1.5, verticalSpacing: 1.5) {
            GridRow {
                thumb(Preset.moodboard[0])
                thumb(Preset.moodboard[1])
            }
            GridRow {
                thumb(Preset.moodboard[2])
                thumb(Preset.moodboard[3])
            }
        }
        .saturation(isOn ? 1 : 0)
        .opacity(isOn ? 1 : 0.5)
    }

    private func thumb(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 10, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
    }
}

/// Soft light send button with a dark arrow. While busy it shows a rolling binary readout.
private struct SendButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.98), Color(white: 0.78)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Circle().stroke(.white.opacity(0.6), lineWidth: 1)
                if isBusy {
                    TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
                        Text(verbatim: bits(at: timeline.date))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(white: 0.2))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(white: 0.25))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: isBusy)
        }
        .buttonStyle(PressableStyle())
        .disabled(isBusy)
        .accessibilityLabel(isBusy ? "Generating" : "Generate")
    }

    private func bits(at date: Date) -> String {
        let tick = Int(date.timeIntervalSinceReferenceDate / 0.08)
        var output = ""
        for index in 0..<3 {
            output += DecodeMath.hash(index, tick, 21) & 1 == 0 ? "0" : "1"
        }
        return output
    }
}
