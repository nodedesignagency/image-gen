import SwiftUI

/// Value pushed onto the navigation stack when a finished image is tapped.
struct ShotRoute: Hashable {
    let shotID: UUID
    let imageName: String
    let title: String
    let prompt: String
    let seed: Int
}

/// A white "folder" card: label tab on top, 2×2 grid of shots inside.
struct BoardView: View {
    let board: Board
    let zoom: Namespace.ID

    private let columns = [
        GridItem(.flexible(), spacing: Theme.cardPadding),
        GridItem(.flexible(), spacing: Theme.cardPadding),
    ]

    var body: some View {
        let isHidden = board.phase == .linking

        VStack(alignment: .leading, spacing: 0) {
            BoardTab(board: board)

            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: columns, spacing: Theme.cardPadding) {
                    ForEach(Array(board.shots.enumerated()), id: \.element.id) { index, shot in
                        ShotCell(board: board, shot: shot, zoom: zoom)
                            .opacity(isHidden ? 0 : 1)
                            .scaleEffect(isHidden ? 0.9 : 1)
                            .animation(.spring(duration: 0.45, bounce: 0.25).delay(Double(index) * 0.06), value: isHidden)
                    }
                }

                if board.kind == .generation {
                    BoardFooter(board: board)
                }
            }
            .padding(Theme.cardPadding)
            .background(Theme.card, in: BoardCardShape())
        }
        .compositingGroup()
        .cardShadow()
        .opacity(isHidden ? 0 : 1)
        .scaleEffect(isHidden ? 0.94 : 1, anchor: .top)
    }
}

private struct BoardTab: View {
    let board: Board

    var body: some View {
        HStack(spacing: 7) {
            icon
                .frame(width: 16, height: 16)

            Group {
                if board.kind == .generation {
                    ScrambleText(text: board.title, delay: 0.5)
                } else {
                    Text(board.title)
                }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)

            Text(verbatim: board.phase == .done ? "\(board.shots.count)" : "\(board.decodedCount)/\(board.shots.count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.secondary)
                .contentTransition(.numericText())
                .animation(.smooth, value: board.decodedCount)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .frame(minWidth: 96, alignment: .leading)
        .background(Theme.card, in: FolderTabShape())
    }

    @ViewBuilder private var icon: some View {
        switch (board.kind, board.phase) {
        case (.moodboard, _):
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondary)
        case (.generation, .done):
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
        case (.generation, _):
            LiveDot()
        }
    }
}

/// Pulsing accent dot shown while a board is still decoding.
private struct LiveDot: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.25))
                .frame(width: 14, height: 14)
                .scaleEffect(pulse ? 1 : 0.4)
                .opacity(pulse ? 0 : 1)
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

private struct ShotCell: View {
    let board: Board
    let shot: Shot
    let zoom: Namespace.ID

    var body: some View {
        if shot.isDecoded {
            NavigationLink(value: route) {
                tile
            }
            .buttonStyle(PressableStyle())
        } else {
            tile
        }
    }

    private var route: ShotRoute {
        ShotRoute(
            shotID: shot.id,
            imageName: shot.imageName,
            title: board.title,
            prompt: board.prompt.isEmpty ? "Reference image from your moodboard." : board.prompt,
            seed: shot.seed
        )
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cellRadius, style: .continuous)
        return Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay { content }
            .clipShape(shape)
            .contentShape(shape)
            .matchedTransitionSource(id: shot.id, in: zoom)
    }

    @ViewBuilder private var content: some View {
        if shot.isDecoded {
            Image(shot.imageName)
                .resizable()
                .scaledToFill()
        } else if board.phase == .decoding {
            DecodingImage(imageName: shot.imageName, start: shot.start, duration: shot.duration, seed: shot.seed)
        } else {
            Theme.placeholder
        }
    }
}

private struct BoardFooter: View {
    let board: Board

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(board.prompt)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: status)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(board.phase == .done ? Theme.secondary : Theme.accent)
                .contentTransition(.numericText())
                .animation(.smooth, value: status)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }

    private var status: String {
        switch board.phase {
        case .linking, .framing:
            return "reading moodboard…"
        case .decoding:
            return "decoding \(board.decodedCount) of \(board.shots.count)"
        case .done:
            let seconds = String(format: "%.1f", board.elapsed ?? 0)
            return "\(board.shots.count) images · 3:4 · \(seconds)s"
        }
    }
}
