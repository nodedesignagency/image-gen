import SwiftUI

/// Pro upsell sheet. Purely cosmetic: the button just flips the account to Pro.
struct PaywallView: View {
    @Environment(Studio.self) private var studio
    @Environment(\.dismiss) private var dismiss
    @State private var yearly = true
    @State private var heroStart = Date.now.addingTimeInterval(0.35)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero

                VStack(alignment: .leading, spacing: 8) {
                    Text("Decode Pro")
                        .font(.display)
                        .tracking(-0.8)
                        .foregroundStyle(Theme.ink)
                    Text("More bits, more takes. Everything you need to make a series.")
                        .font(.prose)
                        .foregroundStyle(Theme.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    feature("sparkle", "1,000 credits every month")
                    feature("arrow.up.left.and.arrow.down.right", "2× upscale on every image")
                    feature("square.grid.2x2", "Unlimited moodboards")
                    feature("bolt", "Priority decoding queue")
                }

                VStack(spacing: 10) {
                    PlanOption(title: "Yearly", price: "$39.99 / year", note: "Save 58%", isSelected: yearly) { yearly = true }
                    PlanOption(title: "Monthly", price: "$7.99 / month", note: nil, isSelected: !yearly) { yearly = false }
                }

                Button {
                    studio.upgrade()
                    dismiss()
                } label: {
                    Text("Start 7-day free trial")
                        .font(.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.ink, in: Capsule())
                }
                .buttonStyle(PressableStyle())

                Text("Demo only. Nothing is charged.")
                    .font(.note)
                    .foregroundStyle(Theme.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                CircleIcon(systemImage: "xmark")
            }
            .buttonStyle(PressableStyle())
            .padding(16)
            .accessibilityLabel("Close")
        }
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
        return Color.clear
            .frame(height: 240)
            .overlay {
                DecodeOnce(imageName: "afterdark-1", start: heroStart, duration: 2.6, seed: 9, density: 1.2)
            }
            .clipShape(shape)
            .overlay(alignment: .bottomLeading) {
                Text(verbatim: "PRO")
                    .font(.monoBadge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accent, in: Capsule())
                    .padding(14)
            }
            .cardShadow()
            .padding(.top, 28)
    }

    private func feature(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.accent.opacity(0.09), in: Circle())
            Text(text)
                .font(.prose)
                .foregroundStyle(Theme.ink)
        }
    }
}

private struct PlanOption: View {
    let title: String
    let price: String
    let note: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.heading)
                        .foregroundStyle(Theme.ink)
                    Text(price)
                        .font(.monoValue)
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                if let note {
                    Text(note)
                        .font(.monoMeta.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.1), in: Capsule())
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.hairline, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(PressableStyle())
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}
