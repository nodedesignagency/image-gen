import SwiftUI

/// Bottom prompt card: suggestion chips, the text field, settings chips and
/// the generate button.
struct Composer: View {
    @Environment(Studio.self) private var studio
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var studio = studio

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
                TextField("Imagine something…", text: $studio.prompt, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    SettingChip(systemImage: "square.grid.2x2", text: "Moodboard", isOn: true)
                    SettingChip(systemImage: "square.stack", text: "4")
                    SettingChip(systemImage: "rectangle.portrait", text: "3:4")
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
        .padding(.bottom, 6)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Theme.canvas.opacity(0), location: 0),
                    .init(color: Theme.canvas.opacity(0.92), location: 0.35),
                    .init(color: Theme.canvas, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
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

private struct SettingChip: View {
    let systemImage: String
    let text: String
    var isOn = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(isOn ? Theme.accent : Theme.ink.opacity(0.7))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(isOn ? Theme.accent.opacity(0.09) : Theme.canvas, in: Capsule())
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
