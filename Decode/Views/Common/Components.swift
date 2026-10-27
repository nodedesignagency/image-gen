import SwiftUI

/// 2×2 bit grid, echoing a board. `onDark` is all white (no blue) for use
/// beside white text on smoked glass.
struct LogoMark: View {
    var cell: CGFloat = 9
    var onDark = false

    var body: some View {
        let gap = cell * 0.28
        let ink = onDark ? Color.white : Theme.ink
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            GridRow {
                square(ink)
                square(onDark ? ink.opacity(0.55) : Theme.accent)
            }
            GridRow {
                square(ink.opacity(onDark ? 0.3 : 0.22))
                square(ink)
            }
        }
        .accessibilityHidden(true)
    }

    private func square(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: cell * 0.28, style: .continuous)
            .fill(color)
            .frame(width: cell, height: cell)
    }
}

/// Screen title with the app menu on the left and optional trailing controls.
/// Pin it with `.edgeBar(.top)`.
struct TopBar<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AppMenuButton()
            Text(title)
                .font(.screenTitle)
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }
}

extension TopBar where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// Round frosted-glass icon used for top-bar controls.
struct CircleIcon: View {
    let systemImage: String
    var size: CGFloat = 42
    @AppStorage(SettingsKey.reduceEffects) private var reduceEffects = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .glassChrome(in: Circle(), lite: reduceEffects)
    }
}

/// Hamburger menu: the app's navigation now that the tab bar is hidden.
struct AppMenuButton: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        @Bindable var studio = studio

        Menu {
            Picker("Go to", selection: $studio.tab) {
                Label("Create", systemImage: "sparkles").tag(AppTab.create)
                Label("Explore", systemImage: "safari").tag(AppTab.explore)
                Label("Library", systemImage: "photo.stack").tag(AppTab.library)
                Label("Profile", systemImage: "person.crop.circle").tag(AppTab.profile)
            }
            Section {
                Button("New canvas", systemImage: "square.dashed") {
                    studio.resetCanvas()
                    studio.select(.create)
                }
                .disabled(studio.isGenerating)
                Button("Play demo", systemImage: "play.circle") {
                    Task { await Autopilot.run(studio, fromLaunch: false) }
                }
            }
        } label: {
            CircleIcon(systemImage: "line.3.horizontal")
        }
        .accessibilityLabel("Menu")
    }
}

/// A coin: the credits icon. A rim with a ring inside, so it reads as a token
/// rather than anything AI.
struct CreditCoin: View {
    var size: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: size * 0.12)
            Circle().strokeBorder(lineWidth: size * 0.08)
                .padding(size * 0.26)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Gradient initial avatar for made-up creators.
struct Avatar: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let hue = DecodeMath.random(seed, 11, 2)
        let shifted = (hue + 0.14).truncatingRemainder(dividingBy: 1)
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.5, brightness: 0.95),
                        Color(hue: shifted, saturation: 0.75, brightness: 0.72),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// White rounded panel for grouped content.
struct Panel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .cardShadow()
    }
}

/// Small chip holding a symbol and a mono value, like a property in a node
/// editor. `onCard` is a soft grey fill for white surfaces, `onCanvas` a white
/// chip for the grey canvas, `live` an accent chip for something in progress.
struct MetaChip: View {
    enum Tone { case onCard, onCanvas, live }

    let systemImage: String?
    let text: String
    var tone: Tone = .onCard

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(verbatim: text)
                .font(.monoMeta)
                .contentTransition(.numericText())
        }
        .foregroundStyle(tone == .live ? Theme.accent : Theme.ink.opacity(0.72))
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background {
            switch tone {
            case .onCard:
                shape.fill(Theme.ink.opacity(0.05))
            case .onCanvas:
                shape.fill(Theme.card)
                shape.strokeBorder(Theme.hairline, lineWidth: 1)
            case .live:
                shape.fill(Theme.accent.opacity(0.09))
            }
        }
    }
}

/// Lays chips out left to right and wraps onto a new row when they don't fit,
/// so metadata never scrolls or truncates.
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(subviews, width: bounds.width).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + rowHeight), origins)
    }
}

struct ToastView: View {
    let toast: Toast?

    var body: some View {
        ZStack {
            if let toast {
                HStack(spacing: 8) {
                    Image(systemName: toast.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(toast.message)
                        .font(.label)
                        .foregroundStyle(Theme.ink)
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Theme.card, in: Capsule())
                .cardShadow()
                .id(toast.id)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 6)
        .animation(.spring(duration: 0.4, bounce: 0.3), value: toast)
        .allowsHitTesting(false)
    }
}
