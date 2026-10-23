import SwiftUI

/// Splash → onboarding (first run) → tabs. Hosts the paywall sheet and toasts.
struct RootView: View {
    @Environment(Studio.self) private var studio
    @State private var showSplash = true

    var body: some View {
        @Bindable var studio = studio

        ZStack {
            if studio.hasOnboarded {
                MainTabs()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .overlay(alignment: .top) {
            ToastView(toast: studio.toast)
        }
        .sheet(isPresented: $studio.showPaywall) {
            PaywallView()
        }
        .task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation(.smooth(duration: 0.5)) {
                showSplash = false
            }
        }
        .task {
            if Autopilot.isRequestedAtLaunch {
                await Autopilot.run(studio, fromLaunch: true)
            }
        }
    }
}

private struct MainTabs: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        @Bindable var studio = studio

        TabView(selection: $studio.tab) {
            Tab("Explore", systemImage: "safari", value: AppTab.explore) {
                ExploreView()
            }
            Tab("Create", systemImage: "sparkles", value: AppTab.create) {
                CreateView()
            }
            Tab("Library", systemImage: "photo.stack", value: AppTab.library) {
                LibraryView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tint(Theme.ink)
    }
}

private struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            DotGrid().ignoresSafeArea()

            VStack(spacing: 16) {
                LogoMark(cell: 16)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .rotationEffect(.degrees(appeared ? 0 : -45))

                ScrambleText(text: "decode", delay: 0.25, perCharacter: 0.07)
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-1)
                    .foregroundStyle(Theme.ink)
                    .frame(height: 40)

                Text(verbatim: "image generation, bit by bit")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .opacity(appeared ? 1 : 0)
                    .animation(.smooth(duration: 0.6).delay(0.6), value: appeared)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.35)) {
                appeared = true
            }
        }
    }
}
