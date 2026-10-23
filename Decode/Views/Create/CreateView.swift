import SwiftUI

/// The Create tab: a dotted canvas of boards, each new generation cabled to
/// the one before it, with the composer pinned to the bottom.
struct CreateView: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @Namespace private var zoom

    var body: some View {
        @Bindable var studio = studio

        NavigationStack(path: $studio.createPath) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(studio.boards.enumerated()), id: \.element.id) { index, board in
                            if index > 0 {
                                Cable(isLive: board.phase != .done)
                                    .frame(height: 64)
                            }
                            BoardView(board: board, zoom: zoom)
                                .id(board.id)
                        }

                        if studio.boards.count == 1 {
                            EmptyHint()
                                .padding(.top, 28)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .background { DotGrid().ignoresSafeArea() }
                .safeAreaInset(edge: .top, spacing: 0) { CreateHeader() }
                .safeAreaInset(edge: .bottom, spacing: 0) { Composer() }
                .onChange(of: studio.boards.count) { _, _ in
                    guard let last = studio.boards.last else { return }
                    withAnimation(.smooth(duration: 0.7)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ShotRoute.self) { route in
                ShotDetailView(route: route)
                    .navigationTransition(.zoom(sourceID: route.id, in: zoom))
            }
        }
        .sensoryFeedback(trigger: studio.boards.count) { _, _ in
            haptics ? .impact(weight: .medium) : nil
        }
        .sensoryFeedback(trigger: studio.decodeTicks) { _, _ in
            haptics ? .impact(weight: .light, intensity: 0.6) : nil
        }
    }
}

private struct CreateHeader: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        HStack(spacing: 10) {
            LogoMark()
            Text("decode")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)

            Spacer()

            Button {
                studio.showPaywall = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(verbatim: "\(studio.credits)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(value: Double(studio.credits)))
                        .animation(.smooth, value: studio.credits)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Theme.card, in: Capsule())
                .cardShadow()
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("\(studio.credits) credits")

            Menu {
                Button("New canvas", systemImage: "square.dashed") {
                    withAnimation(.smooth) { studio.resetCanvas() }
                }
                .disabled(studio.isGenerating)
            } label: {
                CircleIcon(systemImage: "ellipsis")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background { CanvasFade(edge: .top) }
    }
}

private struct EmptyHint: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: "01100100")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.accent)
            Text("Pick a suggestion or describe a shot.\nIt decodes right here, bit by bit.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
}
