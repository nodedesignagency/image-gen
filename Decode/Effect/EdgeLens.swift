import SwiftUI

extension View {
    /// Edge lens (see `edgeLens` in `Shaders.metal`): as this view slides under
    /// the header it is magnified toward the top edge, smears along the way and
    /// splits into colour. Apply it to each board inside the scroll view, never
    /// to the ScrollView itself. The shader only runs while the view reaches
    /// the band.
    ///
    /// `band` is the y, in `.global` space, where the lens ends. Assumes the
    /// view is centred horizontally on screen, as boards are.
    func edgeLens(band: CGFloat, isEnabled: Bool) -> some View {
        let stretch: CGFloat = 0.36   // of the band
        let widen: CGFloat = 0.18
        let smear: CGFloat = 0.14
        let fringe: CGFloat = 0.05    // colour channels drift apart along the stretch
        let reach = band * (stretch + smear + fringe)
        return visualEffect { content, proxy in
            let top = proxy.frame(in: .global).minY
            let centerX = proxy.size.width / 2
            return content.layerEffect(
                ShaderLibrary.edgeLens(
                    .float(top),
                    .float(band),
                    .float(stretch),
                    .float(widen),
                    .float(smear),
                    .float(fringe),
                    .float(centerX)
                ),
                maxSampleOffset: CGSize(width: (centerX * widen).rounded(.up), height: reach.rounded(.up)),
                isEnabled: isEnabled && top < band
            )
        }
    }
}
