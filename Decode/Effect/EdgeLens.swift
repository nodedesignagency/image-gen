import OSLog
import SwiftUI

private let lensLog = Logger(subsystem: "com.nodedesign.decode", category: "lens")
private var lensLogCount = 0

/// Where the canvas's thick-glass edges sit, in the `.global` space that the
/// boards measure themselves in. (Whatever that space's origin is, header,
/// panel and boards are all measured in it, so the numbers agree.)
/// Zero bands switch that edge off.
struct EdgeLensBands: Equatable {
    /// y where the top band ends (below the header blur).
    var top: CGFloat = 0
    /// y where the bottom band starts (above the composer's glass).
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
            let frame = proxy.frame(in: .global)
            let reaches = frame.minY < bands.top || frame.maxY > bands.bottomStart
            let centerX = proxy.size.width / 2
            if lensLogCount < 3, reaches {
                lensLogCount += 1
                lensLog.log("board at \(frame.minY, format: .fixed(precision: 0))…\(frame.maxY, format: .fixed(precision: 0)) in bands top \(bands.top, format: .fixed(precision: 0)) bottomStart \(bands.bottomStart, format: .fixed(precision: 0))")
            }
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
