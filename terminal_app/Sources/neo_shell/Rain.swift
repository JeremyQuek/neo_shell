// The rain shader. Kept as source and compiled at launch (a few ms), because
// `swift build` doesn't compile .metal files into a library.
//
// The grid never moves. Every column has a drop falling one row per step
// (Config.rainFPS steps/s); a cell's brightness is fade^(steps since the drop passed it),
// and its glyph is picked by hashing the step it was lit at, so each pass
// leaves new letters behind. All of it is a pure function of the step
// counter: the CPU sends one number per frame.
let rainShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 cellPx;      // cell size in drawable pixels
    uint step;          // drop steps since launch
    uint rows;          // visible rows
    uint glyphCount;
    uint gapMin;
    uint gapSpan;
    float fade;
    float opacity;
    float3 color;
};

struct VOut { float4 position [[position]]; };

// One triangle that covers the whole drawable
vertex VOut rain_vertex(uint id [[vertex_id]]) {
    float2 p = float2((id << 1) & 2, id & 2);
    VOut out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

static uint hash(uint x) {
    x ^= x >> 16; x *= 0x7feb352du;
    x ^= x >> 15; x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

fragment float4 rain_fragment(VOut in [[stage_in]],
                              constant Uniforms &u [[buffer(0)]],
                              texture2d<float> atlas [[texture(0)]]) {
    uint2 cell = uint2(in.position.xy / u.cellPx);
    uint col = cell.x, row = cell.y;

    // Each column: a drop falls through `rows`, then waits `gap` steps
    uint seed = hash(col * 2654435761u + 1u);
    uint cycle = u.rows + u.gapMin + seed % (u.gapSpan + 1u);
    uint t = u.step + hash(seed) % cycle;     // per-column phase
    uint head = t % cycle;
    uint age = (head + cycle - row % cycle) % cycle;

    float brightness = pow(u.fade, float(age));
    if (brightness < 0.01) return float4(0.0, 0.0, 0.0, 1.0);

    // Glyph written when the drop passed this cell; fixed until the next pass
    uint glyph = hash(col * 73856093u ^ row * 19349663u ^ (t - age) * 83492791u) % u.glyphCount;
    float2 inCell = fract(in.position.xy / u.cellPx);
    float2 uv = float2((float(glyph) + inCell.x) / float(u.glyphCount), inCell.y);
    constexpr sampler s(filter::linear, address::clamp_to_edge);
    float coverage = atlas.sample(s, uv).r;

    return float4(u.color * (coverage * brightness * u.opacity), 1.0);
}
"""

// Must match `Uniforms` in the shader byte for byte
struct RainUniforms {
    var cellPx: SIMD2<Float>
    var step: UInt32
    var rows: UInt32
    var glyphCount: UInt32
    var gapMin: UInt32
    var gapSpan: UInt32
    var fade: Float
    var opacity: Float
    var color: SIMD3<Float>
}
