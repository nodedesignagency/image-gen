import SwiftUI

/// Where the canvas's thick-glass edges sit, in the scroll view's coordinates.
/// Zero bands switch that edge off.
struct EdgeLensBands: Equatable {
    /// Screen y where the top band ends (below the header blur).
    var top: CGFloat = 0
    /// Screen y where the bottom band starts (above the composer).
    var bottomStart: CGFloat = .infinity
    /// Height of the bottom band, down to the screen's bottom edge.
    var bottom: CGFloat = 0
}

extension View {
    /// Edge lens (see `edgeLens` in `Shaders.metal`): as this view slides under
    /// the header or the composer it is magnified toward that edge and smears
    /// along the way. Apply it to each board inside the scroll view, never to
    /// the ScrollView itself. The shader only runs while the view reaches a band.
    ///
    /// Assumes the view is centred horizontally on screen, as boards are.
    func edgeLens(_ bands: EdgeLensBands, isEnabled: Bool) -> some View {
        let stretch: CGFloat = 0.34   // of the band, per edge
        let widen: CGFloat = 0.14
        let smear: CGFloat = 0.08
        let reach = max(bands.top, bands.bottom) * (stretch + smear)
        return visualEffect { content, proxy in
            let frame = proxy.frame(in: .scrollView)
            let reaches = frame.minY < bands.top || frame.maxY > bands.bottomStart
            let centerX = proxy.size.width / 2
            return content.layerEffect(
                ShaderLibrary.edgeLens(
                    .float(frame.minY),
                    .float(bands.top),
                    .float(bands.bottomStart),
                    .float(max(bands.bottom, 1)),
                    .float(stretch),
                    .float(widen),
                    .float(smear),
                    .float(centerX)
                ),
                maxSampleOffset: CGSize(width: (centerX * widen).rounded(.up), height: reach.rounded(.up)),
                isEnabled: isEnabled && reaches
            )
        }
    }
}
