import SwiftUI

/// 2×2 bit grid, echoing a board.
struct LogoMark: View {
    var cell: CGFloat = 9

    var body: some View {
        let gap = cell * 0.28
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            GridRow {
                square(Theme.ink)
                square(Theme.accent)
            }
            GridRow {
                square(Theme.ink.opacity(0.22))
                square(Theme.ink)
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

/// Large screen title with optional trailing controls, fading into the canvas below.
struct TopBar<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .background { CanvasFade(edge: .top) }
    }
}

extension TopBar where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// Solid canvas colour that fades out toward the content, for pinned bars.
struct CanvasFade: View {
    var edge: VerticalEdge

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.canvas, location: 0),
                .init(color: Theme.canvas, location: 0.72),
                .init(color: Theme.canvas.opacity(0), location: 1),
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .ignoresSafeArea()
    }
}

/// Round white icon button used in top bars.
struct CircleIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: 34, height: 34)
            .background(Theme.card, in: Circle())
            .cardShadow()
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

/// Small grey capsule holding a symbol and a value.
struct MetaChip: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(Theme.ink.opacity(0.7))
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Theme.card, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.hairline, lineWidth: 1) }
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
                        .font(.system(size: 14, weight: .medium))
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
