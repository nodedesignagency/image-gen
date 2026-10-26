import SwiftUI

/// The label tab that sits on a board's top-leading corner.
///
/// It draws slightly outside its own frame: `flare` adds a concave fillet to the
/// right so the tab melts into the card's top edge, and the bottom is tucked 1pt
/// under the card to hide the seam.
struct FolderTabShape: Shape {
    var radius: CGFloat = 12
    var flare: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height / 2)
        let bottom = rect.maxY + 1
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + r, y: rect.minY),
            radius: r
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: r
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX + flare, y: rect.maxY),
            radius: flare
        )
        path.addLine(to: CGPoint(x: rect.maxX + flare, y: bottom))
        path.closeSubpath()
        return path
    }
}

/// Card body under a tab: square top-leading corner, rounded everywhere else.
struct BoardCardShape: Shape {
    var radius: CGFloat = Theme.cardRadius

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: 0,
                bottomLeading: radius,
                bottomTrailing: radius,
                topTrailing: radius
            ),
            style: .continuous
        )
        .path(in: rect)
    }
}

/// A board's tab and card as one outline, sized by the measured tab. Drawn
/// behind a board to cast its shadow.
struct FolderShape: Shape {
    var tabSize: CGSize

    func path(in rect: CGRect) -> Path {
        let tab = FolderTabShape().path(in: CGRect(origin: rect.origin, size: tabSize))
        let card = BoardCardShape().path(
            in: CGRect(x: rect.minX, y: rect.minY + tabSize.height, width: rect.width, height: max(0, rect.height - tabSize.height))
        )
        return tab.union(card)
    }
}

/// Light dot lattice behind everything, like a node editor's canvas.
struct DotGrid: View {
    var spacing: CGFloat = 20

    var body: some View {
        Canvas { context, size in
            var dots = Path()
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    dots.addEllipse(in: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6))
                    x += spacing
                }
                y += spacing
            }
            context.fill(dots, with: .color(Theme.ink.opacity(0.09)))
        }
        .background(Theme.canvas)
    }
}

/// Small scale-down on press for tappable tiles.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}
