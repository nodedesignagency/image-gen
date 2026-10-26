import SwiftUI

struct ProfileView: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.decodeSpeed) private var speed: DecodeSpeed = .normal
    @AppStorage(SettingsKey.revealFeed) private var revealFeed = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    identity
                    plan
                    settings
                    demo

                    Text(verbatim: "decode 1.0 · front-end demo · images from Unsplash")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .edgeBar(.top) {
                TopBar("Profile") {
                    CircleIcon(systemImage: "gearshape")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var identity: some View {
        Panel {
            HStack(spacing: 14) {
                Avatar(name: "Node Design", size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Node Design")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if studio.isPro {
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.accent, in: Capsule())
                        }
                    }
                    Text(verbatim: "@nodedesign")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            HStack(spacing: 0) {
                stat("\(studio.generatedBoards.count)", "generations")
                stat("\(studio.imageCount)", "images")
                stat("\(studio.favorites.count)", "favourites")
            }
            .padding(.vertical, 14)
        }
    }

    private var plan: some View {
        let total = studio.isPro ? Studio.proCredits : Studio.freeCredits
        let fraction = min(1, Double(studio.credits) / Double(total))

        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(studio.isPro ? "Decode Pro" : "Free plan", systemImage: "sparkle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(verbatim: "\(studio.credits) / \(total)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.secondary)
                        .contentTransition(.numericText())
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.ink.opacity(0.07))
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(8, proxy.size.width * fraction))
                    }
                }
                .frame(height: 8)
                .animation(.smooth, value: fraction)

                Text(studio.isPro ? "Credits refill on the 1st of every month." : "Each image costs one credit. Pro gives you 1,000 a month.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)

                if !studio.isPro {
                    Button {
                        studio.showPaywall = true
                    } label: {
                        Text("Upgrade to Pro")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Theme.ink, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 2)
                }
            }
            .padding(16)
        }
    }

    private var settings: some View {
        Panel {
            SectionLabel("Preferences")

            Toggle(isOn: $haptics) {
                SettingRow(systemImage: "iphone.radiowaves.left.and.right", title: "Haptics")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 52)

            Toggle(isOn: $revealFeed) {
                SettingRow(systemImage: "square.grid.3x3.middle.filled", title: "Decode Explore tiles")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.leading, 52)

            VStack(alignment: .leading, spacing: 10) {
                SettingRow(systemImage: "speedometer", title: "Decode speed")
                Picker("Decode speed", selection: $speed) {
                    ForEach(DecodeSpeed.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .tint(Theme.accent)
    }

    private var demo: some View {
        Panel {
            SectionLabel("Demo")

            ActionRow(systemImage: "play.circle", title: "Play demo", detail: "Types, generates and tours the app on its own") {
                Task { await Autopilot.run(studio, fromLaunch: false) }
            }

            Divider().padding(.leading, 52)

            ActionRow(systemImage: "rectangle.portrait.on.rectangle.portrait", title: "Replay onboarding", detail: nil) {
                studio.restartOnboarding()
            }

            Divider().padding(.leading, 52)

            ActionRow(systemImage: "square.dashed", title: "New canvas", detail: nil) {
                studio.resetCanvas()
                studio.select(.create)
            }
            .padding(.bottom, 6)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SectionLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

private struct SettingRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
        }
    }
}

private struct ActionRow: View {
    let systemImage: String
    let title: String
    let detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
