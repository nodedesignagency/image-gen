import SwiftUI

extension View {
    /// Edge lens (see `Shaders.metal`): as this view slides under the header it
    /// stretches toward the top edge and its sides draw in. Apply it to each
    /// board and cable inside the scroll view, never to the ScrollView itself.
    /// The shader only runs while the view actually reaches the band.
    ///
    /// `band` is the screen y where the header's blur ends. Assumes the view is
    /// centred horizontally on screen, as boards and cables are.
    func edgeLens(band: CGFloat, isEnabled: Bool) -> some View {
        visualEffect { content, proxy in
            let top = proxy.frame(in: .scrollView).minY
            let stretch = band * 0.3
            let pinch: CGFloat = 0.08
            let centerX = proxy.size.width / 2
            return content.distortionEffect(
                ShaderLibrary.edgeLens(.float(top), .float(band), .float(stretch), .float(pinch), .float(centerX)),
                maxSampleOffset: CGSize(width: (centerX * pinch).rounded(.up), height: stretch.rounded(.up)),
                isEnabled: isEnabled && top < band
            )
        }
    }
}
