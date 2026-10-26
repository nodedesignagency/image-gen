#include <metal_stdlib>
using namespace metal;

/// Edge lens for the canvas, in screen space so every board and cable bends by
/// the same amount at the same height. Inside the top `band` points, output
/// pixels sample from further down (content stretches up into the header blur)
/// and further out from the centre (the card's sides draw in, so it reads as
/// bending away over the edge).
///
/// `originY` is the view's top in screen points, `centerX` the screen's
/// horizontal centre in the view's own coordinates. Stretch stays under a third
/// of the band so the mapping never folds back on itself.
[[ stitchable ]] float2 edgeLens(float2 position, float originY, float band, float stretch, float pinch, float centerX) {
    float screenY = position.y + originY;
    if (screenY >= band) {
        return position;
    }
    float t = 1.0f - max(screenY, 0.0f) / band;   // 0 at the band's bottom, 1 at the edge
    float ease = t * t;
    return float2(
        position.x + (position.x - centerX) * pinch * ease,
        position.y + stretch * ease
    );
}
