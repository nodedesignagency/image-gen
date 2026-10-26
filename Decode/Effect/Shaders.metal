#include <metal_stdlib>
using namespace metal;

/// Edge lens for the canvas: inside the top `band` points, output pixels sample
/// from further down, so content gets stretched toward the edge as it slides
/// under the header blur, like glass bending what passes beneath it.
[[ stitchable ]] float2 edgeLens(float2 position, float band, float strength) {
    if (position.y >= band) {
        return position;
    }
    float t = 1.0 - position.y / band;   // 0 at the band's bottom, 1 at the edge
    float ease = t * t * t;
    return float2(position.x, position.y + ease * strength);
}
