import SwiftUI

/// The link between two boards: leaves the bottom of the previous card near its
/// trailing edge, steps across, and drops into the next card's tab.
/// Draws itself in on appear; while `isLive`, accent bits stream along it.
struct Cable: View {
    var isLive: Bool

    @State private var drawn: CGFloat = 0

    private static let startInset: CGFloat = 64
    private static let endX: CGFloat = 44
    private static let cornerRadius: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let route = Self.route(in: proxy.size)
            let start = CGPoint(x: proxy.size.width - Self.startInset, y: 0)
            let end = CGPoint(x: Self.endX, y: proxy.size.height)

            ZStack {
                route
                    .trim(from: 0, to: drawn)
                    .stroke(Theme.card, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.07), radius: 2, y: 1)

                if isLive {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                        let phase = (timeline.date.timeIntervalSinceReferenceDate * 36)
                            .truncatingRemainder(dividingBy: 12)
                        route
                            .trim(from: 0, to: drawn)
                            .stroke(
                                Theme.accent,
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [0.1, 11.9], dashPhase: -CGFloat(phase))
                            )
                    }
                    .transition(.opacity)
                }

                Port(isLive: isLive)
                    .position(start)

                Port(isLive: isLive)
                    .position(end)
                    .opacity(drawn > 0.98 ? 1 : 0)
            }
            .animation(.smooth(duration: 0.3), value: isLive)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55)) {
                drawn = 1
            }
        }
        .accessibilityHidden(true)
    }

    static func route(in size: CGSize) -> Path {
        let startX = size.width - startInset
        let midY = size.height / 2
        var path = Path()
        path.move(to: CGPoint(x: startX, y: 0))
        path.addArc(
            tangent1End: CGPoint(x: startX, y: midY),
            tangent2End: CGPoint(x: endX, y: midY),
            radius: cornerRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: endX, y: midY),
            tangent2End: CGPoint(x: endX, y: size.height),
            radius: cornerRadius
        )
        path.addLine(to: CGPoint(x: endX, y: size.height))
        return path
    }
}

/// Little socket where the cable plugs into a card.
private struct Port: View {
    var isLive: Bool

    var body: some View {
        Circle()
            .fill(Theme.card)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .fill(isLive ? Theme.accent : Theme.ink.opacity(0.18))
                    .frame(width: 4, height: 4)
            }
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}
