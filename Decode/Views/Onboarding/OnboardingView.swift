import SwiftUI

/// Three pages, each with a picture that decodes when the page comes into view.
struct OnboardingView: View {
    @Environment(Studio.self) private var studio

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "golden-2",
            kicker: "01",
            title: "Type anything.",
            body: "Describe a shot in your own words. Decode reads your moodboard for taste."
        ),
        OnboardingPage(
            imageName: "afterdark-2",
            kicker: "10",
            title: "Watch it decode.",
            body: "Every image arrives bit by bit, ones and zeros resolving into pixels."
        ),
        OnboardingPage(
            imageName: "deepblue-3",
            kicker: "11",
            title: "Keep what you love.",
            body: "Remix, upscale and share. Your library keeps every take."
        ),
    ]

    var body: some View {
        @Bindable var studio = studio
        let isLast = studio.onboardingPage == pages.count - 1

        VStack(spacing: 0) {
            HStack {
                LogoMark()
                Text("decode")
                    .font(.sans(19, .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Skip") {
                    studio.finishOnboarding()
                }
                .font(.label)
                .foregroundStyle(Theme.secondary)
                .opacity(isLast ? 0 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            TabView(selection: $studio.onboardingPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page, seed: index * 13 + 5, isActive: studio.onboardingPage == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth(duration: 0.4), value: studio.onboardingPage)

            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == studio.onboardingPage ? Theme.ink : Theme.ink.opacity(0.15))
                        .frame(width: index == studio.onboardingPage ? 22 : 6, height: 6)
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.3), value: studio.onboardingPage)
            .padding(.bottom, 20)

            Button {
                if isLast {
                    studio.finishOnboarding()
                } else {
                    studio.onboardingPage += 1
                }
            } label: {
                Text(isLast ? "Start creating" : "Continue")
                    .font(.button)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.ink, in: Capsule())
                    .contentTransition(.opacity)
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background { DotGrid().ignoresSafeArea() }
    }
}

struct OnboardingPage {
    let imageName: String
    let kicker: String
    let title: String
    let body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let seed: Int
    let isActive: Bool

    @State private var start: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    DecodeOnce(imageName: page.imageName, start: start, duration: 2.6, seed: seed, density: 1.25)
                }
                .clipShape(shape)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Theme.card)
                        .cardShadow()
                }
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: page.kicker)
                    .font(.monoMeta.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(page.title)
                    .font(.display)
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
                Text(page.body)
                    .font(.prose)
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .onChange(of: isActive, initial: true) { _, active in
            if active, start == nil {
                start = .now.addingTimeInterval(0.25)
            }
        }
    }
}
