#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Shared noise (mirrors DecodeMath in Swift, so Swift-side timing matches)

static uint dhash(int a, int b, int c) {
    uint h = uint(a) * 0x8DA6B343u;
    h ^= uint(b) * 0xD8163841u;
    h ^= uint(c) * 0xCB1AB31Fu;
    h ^= h >> 15;
    h *= 0x2C1B3C6Du;
    h ^= h >> 12;
    h *= 0x297A2D39u;
    h ^= h >> 15;
    return h;
}

static float drandom(int a, int b, int c) {
    return float(dhash(a, b, c)) / 4294967295.0f;
}

/// Half smoothstep: starts and lands softly without stalling in the middle.
static float dease(float p) {
    float s = p * p * (3.0f - 2.0f * p);
    return p + (s - p) * 0.5f;
}

/// 1D value noise, smooth across neighbouring columns.
static float dnoise(float x, int seed) {
    float fl = floor(x);
    int i = int(fl);
    float f = x - fl;
    float u = f * f * (3.0f - 2.0f * f);
    return mix(drandom(i, seed, 31), drandom(i + 1, seed, 31), u);
}

constant float kBand = 0.30f;    // height of the tinted glyph band trailing the front
constant float kJitter = 0.22f;  // how far columns may lag behind each other

/// Normalised y of the decode front in `column` at `progress` (0...1).
static float dhead(int column, float progress, int seed) {
    float lag = 0.72f * dnoise(float(column) * 0.3f, seed) + 0.28f * drandom(column, seed, 13);
    return dease(progress) * (1.0f + kBand + kJitter) - lag * kJitter;
}

// MARK: - Glyphs, drawn as distance fields so no text is rasterised

static float dsegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0f, 1.0f);
    return length(pa - ba * h);
}

static float dcoverage(float d, float halfWidth) {
    return 1.0f - smoothstep(halfWidth - 0.35f, halfWidth + 0.35f, d);
}

/// "0": an oval ring. `p` is relative to the glyph centre, `fs` the font size in points.
static float glyphZero(float2 p, float fs) {
    float2 radii = float2(0.26f, 0.36f) * fs;
    float d = (length(p / radii) - 1.0f) * radii.x;
    return dcoverage(abs(d), 0.065f * fs);
}

/// "1": a stem with a flag at the top left and a foot, like SF Mono's.
static float glyphOne(float2 p, float fs) {
    float w = 0.065f * fs;
    float stem = dsegment(p, float2(0.0f, -0.34f * fs), float2(0.0f, 0.34f * fs));
    float flag = dsegment(p, float2(-0.2f * fs, -0.2f * fs), float2(0.0f, -0.34f * fs));
    float foot = dsegment(p, float2(-0.2f * fs, 0.34f * fs), float2(0.2f * fs, 0.34f * fs));
    return dcoverage(min(stem, min(flag, foot)), w);
}

// MARK: - Binary reveal

constant float3 kAccent = float3(0.176f, 0.357f, 1.0f);
constant float3 kInk = float3(0.067f, 0.067f, 0.075f);
constant float3 kPlaceholder = float3(0.933f, 0.933f, 0.925f);

/// The moving part of the decode, as an overlay for a plain photo underneath.
/// Returns premultiplied colour: the placeholder covers the photo where it
/// hasn't decoded yet (fading out behind each column's front), and the bits
/// sit on top: accent blue at the front, the picture's own colour behind it
/// (from `palette`, r g b per glyph, row by row), faint noise with brighter
/// drops below it. `grid` is columns and rows, computed in Swift.
[[ stitchable ]] half4 decodeOverlay(float2 position, half4 color, float2 size, float2 grid, float progress, float time, float seedValue, float density, device const float *palette, int paletteCount) {
    int seed = int(seedValue);
    int columns = max(1, int(grid.x));
    int rows = max(1, int(grid.y));
    float cellW = size.x / float(columns);
    float rowH = size.y / float(rows);
    int column = clamp(int(position.x / cellW), 0, columns - 1);
    int row = clamp(int(position.y / rowH), 0, rows - 1);
    float rowStep = 1.0f / float(rows);
    float head = dhead(column, progress, seed);

    // How much placeholder still covers the photo: none above the column's
    // tail, fading in toward its head, all of it below.
    float solid = (head - kBand) * size.y;
    float fadeEnd = (head - kBand * 0.15f) * size.y;
    float imageAlpha = position.y < solid ? 1.0f : 1.0f - (position.y - solid) / max(fadeEnd - solid, 0.001f);
    float cover = 1.0f - clamp(imageAlpha, 0.0f, 1.0f);

    float y = (float(row) + 0.5f) * rowStep;
    float dist = head - y;
    if (dist > kBand) {
        return half4(half3(kPlaceholder * cover), half(cover));   // fully decoded: transparent
    }

    // Each glyph flips at its own rate, faster inside the band.
    float rate = 6.0f + 14.0f * drandom(column, row, 99);
    float offset = drandom(row, column, 4) * 10.0f;
    int tick = int(floor(time * (dist >= 0.0f ? rate * 1.6f : rate) + offset));
    bool isOne = (dhash(column, row, tick) & 1u) == 1u;

    float3 tint;
    float opacity;
    if (dist >= 0.0f) {
        float k = dist / kBand;
        if (dist < rowStep) {
            tint = kAccent;
            opacity = 1.0f;
        } else {
            int i = (row * columns + column) * 3;
            float3 p = i + 2 < paletteCount ? float3(palette[i], palette[i + 1], palette[i + 2]) : float3(0.45f, 0.45f, 0.47f);
            tint = mix(p, kAccent, pow(1.0f - k, 3.0f) * 0.55f);
            opacity = pow(1.0f - k, 0.7f) * 0.95f;
        }
    } else {
        // Idle noise below the front, with a brighter drop falling through each column.
        float speed = 0.35f + 0.55f * drandom(column, 3, seed);
        float cycle = time * speed + drandom(column, 5, seed);
        float drop = fract(cycle) * 1.6f - 0.3f;
        float below = -dist;
        float trail = drop - y;
        float boost = (trail > 0.0f && trail < 0.28f) ? 1.0f - trail / 0.28f : 0.0f;
        if (below < 0.06f) {
            tint = kAccent;
            opacity = max(0.07f + boost * 0.22f, 0.55f * (1.0f - below / 0.06f));
        } else {
            tint = kInk;
            opacity = 0.07f + boost * 0.22f;
        }
    }

    float fs = 9.0f * density;
    float2 centre = float2((float(column) + 0.5f) * cellW, (float(row) + 0.5f) * rowH);
    float2 g = position - centre;
    float glyph = (isOne ? glyphOne(g, fs) : glyphZero(g, fs)) * opacity;

    // Glyph over placeholder, premultiplied.
    float3 rgb = tint * glyph + kPlaceholder * cover * (1.0f - glyph);
    float alpha = glyph + cover * (1.0f - glyph);
    return half4(half3(rgb), half(alpha));
}

