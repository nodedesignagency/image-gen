import SwiftUI

extension View {
    /// Edge lens: as a board slides under the header it stretches up into the
    /// top edge, widens a little and fades, like glass magnifying it on its
    /// way out. Pure geometry, which moves the board as already drawn, so
    /// nothing is re-rendered while scrolling. (An earlier Metal version also
    /// smeared and split the colours, but a shader re-renders the board's
    /// photos into a new texture every frame, and that made scrolling crawl.)
    ///
    /// `band` is the y, in `.global` space, where the lens starts. Apply it to
    /// each board inside the scroll view, never to the ScrollView itself.
    func edgeLens(band: CGFloat, isEnabled: Bool) -> some View {
        visualEffect { content, proxy in
            let frame = proxy.frame(in: .global)
            // 0 while the board's top is below the band, 1 once the whole
            // board has slid past it.
            let travel: CGFloat = max(frame.height * 0.85, 1)
            let raw: CGFloat = (band - frame.minY) / travel
            let t: CGFloat = isEnabled ? min(max(raw, 0), 1) : 0
            let e: CGFloat = t * t * (3 - 2 * t)
            return content
                .scaleEffect(x: 1 + 0.07 * e, y: 1 + 0.22 * e, anchor: .bottom)
                .opacity(Double(1 - 0.45 * e))
        }
    }
}
