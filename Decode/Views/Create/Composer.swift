import SwiftUI

/// Bottom prompt card: suggestion chips, the text field with an enhance button,
/// settings menus and the generate button.
struct Composer: View {
    @Environment(Studio.self) private var studio
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var studio = studio
        let hasText = !studio.prompt.trimmingCharacters(in: .whitespaces).isEmpty

        VStack(spacing: 10) {
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
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    TextField("Imagine something…", text: $studio.prompt, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1...4)
                        .focused($isFocused)
                        .padding(.leading, 4)
                        .padding(.top, 5)

                    Button {
                        studio.enhance()
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Theme.accent.opacity(0.09), in: Circle())
                            .symbolEffect(.pulse, isActive: studio.isEnhancing)
                    }
                    .buttonStyle(PressableStyle())
                    .opacity(hasText || studio.isEnhancing ? 1 : 0.35)
                    .accessibilityLabel("Enhance prompt")
                }

                HStack(spacing: 6) {
                    MoodboardChip(isOn: studio.usesMoodboard) {
                        studio.toggleMoodboard()
                    }

                    Menu {
                        Picker("Style", selection: $studio.style) {
                            ForEach(ImageStyle.allCases) { style in
                                Label(style.rawValue, systemImage: style.symbol).tag(style)
                            }
                        }
                    } label: {
                        SettingChip(systemImage: studio.style.symbol, text: studio.style.rawValue)
                    }

                    Menu {
                        Picker("Images", selection: $studio.count) {
                            ForEach([1, 2, 4], id: \.self) { value in
                                Text(value == 1 ? "1 image" : "\(value) images").tag(value)
                            }
                        }
                    } label: {
                        SettingChip(systemImage: "square.stack", text: "\(studio.count)")
                    }

                    Menu {
                        Picker("Aspect ratio", selection: $studio.ratio) {
                            ForEach(AspectRatio.allCases) { ratio in
                                Label(ratio.rawValue, systemImage: ratio.symbol).tag(ratio)
                            }
                        }
                    } label: {
                        SettingChip(systemImage: studio.ratio.symbol, text: studio.ratio.rawValue)
                    }

                    Spacer(minLength: 0)

                    GenerateButton(isBusy: studio.isGenerating) {
                        isFocused = false
                        studio.generate()
                    }
                }
            }
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .cardShadow()
            .padding(.horizontal, 12)
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background { CanvasFade(edge: .bottom) }
    }
}

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
                .foregroundStyle(Theme.ink)
        }
        .padding(.leading, 5)
        .padding(.trailing, 12)
        .padding(.vertical, 5)
        .background(Theme.card, in: Capsule())
        .overlay {
            Capsule().strokeBorder(isSelected ? Theme.accent : Theme.hairline, lineWidth: isSelected ? 1.5 : 1)
        }
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}

/// Tiny 2×2 of the moodboard references; accent ring when linked.
private struct MoodboardChip: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .padding(3)
            .frame(width: 32, height: 32)
            .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent : Color.clear, lineWidth: 1.5)
            }
            .saturation(isOn ? 1 : 0)
            .opacity(isOn ? 1 : 0.6)
            .animation(.smooth(duration: 0.2), value: isOn)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(isOn ? "Moodboard on" : "Moodboard off")
    }

    private func thumb(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 11.5, height: 11.5)
            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
    }
}

private struct SettingChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ink.opacity(0.75))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Theme.canvas, in: Capsule())
    }
}

/// Black circular send button. While busy it shows a rolling binary readout.
private struct GenerateButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.ink)
                if isBusy {
                    TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
                        Text(verbatim: bits(at: timeline.date))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 40, height: 40)
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
