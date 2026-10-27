import SwiftUI

/// The Create tab: a dotted canvas of boards, each new generation cabled to
/// the one before it, with the composer pinned to the bottom.
struct CreateView: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @Namespace private var zoom
    @AppStorage(SettingsKey.edgeLens) private var edgeLens = true
    @AppStorage(SettingsKey.reduceEffects) private var reduceEffects = false
    /// The composer's glass panel, without the suggestions above it.
    @State private var panelHeight: CGFloat = 140
    /// Measured in .global, the same space the boards measure themselves in.
    @State private var headerBottom: CGFloat = 110
    @State private var scroll = ScrollPosition(edge: .top)

    var body: some View {
        @Bindable var studio = studio
        // The edge lens bends boards as they slide under the header. Only
        // the top edge: a board resting above the composer would otherwise
        // run through the shader on every frame of its decode.
        let lensBand = headerBottom + 16
        let lensOn = edgeLens && !reduceEffects

        NavigationStack(path: $studio.createPath) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(studio.boards.enumerated()), id: \.element.id) { index, board in
                            if index > 0 {
                                Cable(isLive: board.phase != .done)
                                    .frame(height: 64)
                                    .zIndex(1) // plugs sit on top of the tab, not under it
                            }
                            BoardView(board: board, zoom: zoom)
                                .edgeLens(band: lensBand, isEnabled: lensOn)
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
                .scrollPosition($scroll)
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
                .edgeBar(.top, lite: reduceEffects) {
                    CreateHeader()
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { headerBottom = $0 }
                }
                // Room for the last board to sit clear of the composer *and*
                // its suggestion row. Fixed while a board generates (the row
                // hides then): a margin that changed mid-scroll cut the camera
                // short. A content margin, not safe-area padding, which fed
                // back into the composer's position.
                .contentMargins(.bottom, panelHeight + Composer.suggestionsHeight + 16, for: .scrollContent)
                // Camera: glide to the bottom as soon as a new board links in,
                // so the cable and the whole 2×2 are on screen for the decode.
                // A beat first so the new board is laid out; New canvas goes
                // back to the top.
                .onChange(of: studio.boards.count) { old, new in
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(50))
                        withAnimation(.smooth(duration: 0.75)) {
                            scroll.scrollTo(edge: new > old ? .bottom : .top)
                        }
                    }
                }
                .onChange(of: studio.boards.last?.phase) { _, phase in
                    // Re-settle once the chips land, in case the user scrolled.
                    guard phase == .done else { return }
                    withAnimation(.smooth(duration: 0.5)) {
                        scroll.scrollTo(edge: .bottom)
                    }
                }

                // Floats ~10pt off the bottom edge, inside the home-indicator area.
                Composer(panelHeight: $panelHeight)
                    .padding(.bottom, 10)
                    .ignoresSafeArea(.container, edges: .bottom)
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

private struct CreateHeader: View {
    @Environment(Studio.self) private var studio
    @AppStorage(SettingsKey.reduceEffects) private var reduceEffects = false

    var body: some View {
        HStack(spacing: 10) {
                AppMenuButton()

                Spacer()

                Button {
                    studio.showPaywall = true
                } label: {
                    HStack(spacing: 5) {
                        CreditCoin(size: 13)
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
                    Button("Get more credits", systemImage: "plus.circle") {
                        studio.showPaywall = true
                    }
                } label: {
                    CircleIcon(systemImage: "ellipsis")
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
