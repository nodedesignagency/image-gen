import SwiftUI

/// The Create tab: a dotted canvas of boards, each new generation cabled to
/// the one before it, with the composer pinned to the bottom.
struct CreateView: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @Namespace private var zoom
    @AppStorage(SettingsKey.edgeLens) private var edgeLens = false
    @State private var composerHeight: CGFloat = 200
    /// Status bar + header: the zone the edge lens and top blur cover.
    @State private var topInset: CGFloat = 110

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
                                    .id(Self.cableID(board))
                                    .zIndex(1) // plugs sit on top of the tab, not under it
                            }
                            BoardView(board: board, zoom: zoom)
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
                    // Content bends toward the top edge as it passes under the
                    // header. Applied to the content, not the ScrollView: Metal
                    // effects can't rasterize UIKit-backed views, and a
                    // ScrollView is one (it renders blank). The band is in
                    // content coordinates, so it follows the scroll offset.
                    .visualEffect { [edgeLens, topInset] content, proxy in
                        content.distortionEffect(
                            ShaderLibrary.edgeLens(.float(topInset + 12 - proxy.frame(in: .scrollView).minY), .float(34)),
                            maxSampleOffset: CGSize(width: 0, height: 34),
                            isEnabled: edgeLens
                        )
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
                .scrollDismissesKeyboard(.interactively)
                .background {
                    ZStack {
                        DotGrid()
                        AmbientWash(images: studio.ambientImages, opacity: 0.5)
                    }
                    .ignoresSafeArea()
                }
                .edgeBar(.top) { CreateHeader() }
                // The composer floats ~10pt off the bottom edge (inside the
                // home-indicator area) rather than sitting above it, and the
                // canvas is padded so the last board can scroll clear of it.
                .overlay(alignment: .bottom) {
                    Composer()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { composerHeight = $0 }
                        .padding(.bottom, 10)
                        .ignoresSafeArea(.container, edges: .bottom)
                }
                .safeAreaPadding(.bottom, max(0, composerHeight - 18))
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
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .contentTransition(.numericText(value: Double(studio.credits)))
                            .animation(.smooth, value: studio.credits)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .contentShape(Capsule())
                    .glassChrome(in: Capsule())
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
