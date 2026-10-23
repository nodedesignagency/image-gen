import SwiftUI

/// The one main screen: a dotted canvas of boards, each new generation
/// cabled to the one before it, with the composer pinned to the bottom.
struct StudioView: View {
    @Environment(Studio.self) private var studio
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
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
                .safeAreaInset(edge: .top, spacing: 0) { Header() }
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
                    .navigationTransition(.zoom(sourceID: route.shotID, in: zoom))
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: studio.boards.count)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: studio.decodeTicks)
    }
}

private struct Header: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        HStack(spacing: 10) {
            LogoMark()
            Text("decode")
                .font(.system(size: 21, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)

            Spacer()

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
            .frame(height: 32)
            .background(Theme.card, in: Capsule())
            .cardShadow()

            Menu {
                Button("New canvas", systemImage: "square.dashed", role: .destructive) {
                    withAnimation(.smooth) { studio.reset() }
                }
                .disabled(studio.isGenerating)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
                    .background(Theme.card, in: Circle())
                    .cardShadow()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Theme.canvas, location: 0),
                    .init(color: Theme.canvas, location: 0.7),
                    .init(color: Theme.canvas.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

/// 2×2 bit grid, echoing a board.
private struct LogoMark: View {
    var body: some View {
        let cell: CGFloat = 9
        Grid(horizontalSpacing: 2.5, verticalSpacing: 2.5) {
            GridRow {
                square(Theme.ink, cell)
                square(Theme.accent, cell)
            }
            GridRow {
                square(Theme.ink.opacity(0.22), cell)
                square(Theme.ink, cell)
            }
        }
        .accessibilityHidden(true)
    }

    private func square(_ color: Color, _ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
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
