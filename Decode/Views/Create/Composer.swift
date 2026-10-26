import SwiftUI

/// Bottom prompt panel in frosted glass: prompt on top, a row of setting
/// chips, then enhance, cost and the send button. Suggestions float above it.
struct Composer: View {
    @Environment(Studio.self) private var studio
    @FocusState private var isFocused: Bool

    /// Bottom corners follow the screen's curve when the panel sits ~10pt from the edge.
    private let panel = UnevenRoundedRectangle(
        cornerRadii: RectangleCornerRadii(topLeading: 30, bottomLeading: 44, bottomTrailing: 44, topTrailing: 30),
        style: .continuous
    )

    var body: some View {
        @Bindable var studio = studio
        let hasText = !studio.prompt.trimmingCharacters(in: .whitespaces).isEmpty

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
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 0) {
                TextField(
                    "Imagine something",
                    text: $studio.prompt,
                    prompt: Text("Imagine something…").foregroundColor(.white.opacity(0.55)),
                    axis: .vertical
                )
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .tint(.white)
                .lineLimit(1...4)
                .focused($isFocused)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 15)

                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 1)

                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        MoodboardChip(isOn: studio.usesMoodboard) {
                            studio.toggleMoodboard()
                        }

                        Menu {
                            Picker("Images", selection: $studio.count) {
                                ForEach([1, 2, 4], id: \.self) { value in
                                    Text(value == 1 ? "1 image" : "\(value) images").tag(value)
                                }
                            }
                        } label: {
                            GlassChip(systemImage: "square.on.square", text: studio.count == 1 ? "1 image" : "\(studio.count) images")
                        }

                        Menu {
                            Picker("Style", selection: $studio.style) {
                                ForEach(ImageStyle.allCases) { style in
                                    Label(style.rawValue, systemImage: style.symbol).tag(style)
                                }
                            }
                        } label: {
                            GlassChip(systemImage: studio.style.symbol, text: studio.style.rawValue)
                        }

                        Menu {
                            Picker("Aspect ratio", selection: $studio.ratio) {
                                ForEach(AspectRatio.allCases) { ratio in
                                    Label(ratio.rawValue, systemImage: ratio.symbol).tag(ratio)
                                }
                            }
                        } label: {
                            GlassChip(systemImage: studio.ratio.symbol, text: studio.ratio.rawValue)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 10)

                HStack(spacing: 8) {
                    Button {
                        studio.enhance()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "wand.and.stars")
                                .symbolEffect(.pulse, isActive: studio.isEnhancing)
                            Text("Enhance")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(hasText || studio.isEnhancing ? 0.85 : 0.5))
                        .padding(.horizontal, 8)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Enhance prompt")

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                        Text(verbatim: "\(studio.count)")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText(value: Double(studio.count)))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay { Capsule().stroke(.white.opacity(0.35), lineWidth: 1) }
                    .animation(.smooth, value: studio.count)
                    .accessibilityLabel("Costs \(studio.count) credits")

                    GenerateButton(isBusy: studio.isGenerating) {
                        isFocused = false
                        studio.generate()
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .background { FrostedGlass(shape: panel) }
            .padding(.horizontal, 10)
        }
        .animation(.smooth(duration: 0.35), value: studio.isGenerating)
    }
}

/// Frosted capsule used for suggestions above the panel.
private struct SuggestionChip: View {
    let preset: Preset
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(preset.images[0])
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            Text(preset.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.leading, 5)
        .padding(.trailing, 13)
        .padding(.vertical, 5)
        .background { FrostedGlass(shape: Capsule(), tintOpacity: 0.36, blur: 16, sheen: 0.14) }
        .overlay {
            if isSelected {
                Capsule().stroke(.white.opacity(0.9), lineWidth: 1.5)
            }
        }
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}

/// Soft translucent capsule inside the panel.
private struct GlassChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
            Text(text)
                .font(.system(size: 15))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 13)
        .frame(height: 40)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

/// Tiny 2×2 of the moodboard references; brighter when linked.
private struct MoodboardChip: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
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
                .opacity(isOn ? 1 : 0.55)

                Text("Moodboard")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(isOn ? 0.92 : 0.55))
            }
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .frame(height: 40)
            .background(.white.opacity(isOn ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .animation(.smooth(duration: 0.2), value: isOn)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(isOn ? "Moodboard on" : "Moodboard off")
    }

    private func thumb(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: 11, height: 11)
            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
    }
}

/// Accent-blue circular send button. While busy it shows a rolling binary readout.
private struct GenerateButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Theme.accent)
                Circle().fill(
                    LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0)], startPoint: .top, endPoint: .center)
                )
                if isBusy {
                    TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
                        Text(verbatim: bits(at: timeline.date))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 44, height: 44)
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
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
