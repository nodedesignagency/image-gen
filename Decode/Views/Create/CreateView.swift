import SwiftUI

/// The Create tab: a dotted canvas of boards, each new generation cabled to
/// the one before it, with the composer pinned to the bottom.
struct CreateView: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @Namespace private var zoom
    @AppStorage(SettingsKey.edgeLens) private var edgeLens = true
    @AppStorage(SettingsKey.reduceEffects) private var reduceEffects = false
    @State private var composerHeight: CGFloat = 200
    /// Status bar + header: the zone the top blur covers.
    @State private var topInset: CGFloat = 110
    /// The canvas's frame in the window; it spans the whole screen.
    @State private var canvasFrame = CGRect(x: 0, y: 0, width: 402, height: 874)

    var body: some View {
        @Bindable var studio = studio
        // Thick-glass edges: boards are magnified as they slide under the
        // header and under the composer. The bands reach well past the bars,
        // as in the reference, so the bend is visible before the blur takes over.
        let lens = EdgeLensBands(
            top: canvasFrame.minY + topInset + 70,
            bottomStart: canvasFrame.maxY - composerHeight - 10 - 50,
            bottom: composerHeight + 60
        )
        let lensOn = edgeLens && !reduceEffects

        NavigationStack(path: $studio.createPath) {
            ScrollViewReader { proxy in
                ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(studio.boards.enumerated()), id: \.element.id) { index, board in
                            if index > 0 {
                                Cable(isLive: board.phase != .done)
                                    .frame(height: 64)
                                    .id(Self.cableID(board))
                                    .zIndex(1) // plugs sit on top of the tab, not under it
                            }
                            BoardView(board: board, zoom: zoom)
                                .edgeLens(lens, isEnabled: lensOn)
                                .id(Self.boardID(board))
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
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { canvasFrame = $0 }
                .scrollDismissesKeyboard(.interactively)
                .background {
                    ZStack {
                        DotGrid()
                        if !reduceEffects {
                            AmbientWash(images: studio.ambientImages, opacity: 0.42)
                        }
                    }
                    .ignoresSafeArea()
                }
                .edgeBar(.top, lite: reduceEffects) { CreateHeader() }
                // Room for the last board to scroll clear of the composer. A
                // content margin, not safe-area padding: padding derived from
                // the composer's own height fed back into its position and
                // lifted it by that height on first appearance.
                .contentMargins(.bottom, max(0, composerHeight - 18), for: .scrollContent)
                // Camera follow: frame the cable as the new board links in, then
                // glide down with the sweep so the bottom row decodes on screen.
                // Both wait a beat so the new views exist before scrolling.
                .onChange(of: studio.boards.count) { _, _ in
                    guard let last = studio.boards.last else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(60))
                        withAnimation(.smooth(duration: 0.8)) {
                            if last.kind == .generation {
                                proxy.scrollTo(Self.cableID(last), anchor: .top)
                            } else {
                                proxy.scrollTo(Self.boardID(last), anchor: .top)
                            }
                        }
                    }
                }
                .onChange(of: studio.boards.last?.phase) { _, phase in
                    guard phase == .decoding, let last = studio.boards.last else { return }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.8 * SettingsKey.speed.multiplier))
                        withAnimation(.smooth(duration: 1.4)) {
                            proxy.scrollTo(Self.boardID(last), anchor: .bottom)
                        }
                    }
                }

                // Floats ~10pt off the bottom edge, inside the home-indicator area.
                Composer()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { composerHeight = $0 }
                    .padding(.bottom, 10)
                    .ignoresSafeArea(.container, edges: .bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
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

// Scroll targets need ids distinct from the ForEach row identity (board.id):
// scrolling to the row id lands on its first child, the cable.
extension CreateView {
    static func cableID(_ board: Board) -> String {
        "cable-\(board.id.uuidString)"
    }

    static func boardID(_ board: Board) -> String {
        "board-\(board.id.uuidString)"
    }
}

private struct CreateHeader: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.reduceEffects) private var reduceEffects = false

    var body: some View {
        GlassGroup {
            HStack(spacing: 10) {
                AppMenuButton()

                Spacer()

                Button {
                    studio.showPaywall = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                        Text(verbatim: "\(studio.credits)")
                            .font(.monoValue.weight(.semibold))
                            .contentTransition(.numericText(value: Double(studio.credits)))
                            .animation(.smooth, value: studio.credits)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .contentShape(Capsule())
                    .glassChrome(in: Capsule(), lite: reduceEffects)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(studio.credits) credits")

                Menu {
                    Button("New canvas", systemImage: "square.dashed") {
                        withAnimation(.smooth) { studio.resetCanvas() }
                    }
                    .disabled(studio.isGenerating)
                    Button("Get more credits", systemImage: "sparkle") {
                        studio.showPaywall = true
                    }
                } label: {
                    CircleIcon(systemImage: "ellipsis")
                }
        }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

private struct EmptyHint: View {
    var body: some View {
        VStack(spacing: 6) {
            Text(verbatim: "01100100")
                .font(.monoMeta)
                .foregroundStyle(Theme.accent)
            Text("Pick a suggestion or describe a shot.\nIt decodes right here, bit by bit.")
                .font(.supporting)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
}
