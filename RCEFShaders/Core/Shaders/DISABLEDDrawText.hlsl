// RCEFShaders text rendering using the local LiberationMono-Bold font atlas.
// Layout positions are in font pixels; the VS converts them to normalized
// viewport coordinates. X is the alignment point; Y is the top of the text.
Texture1D<float4> IniParams : register(t120);
Texture2D<float> Font : register(t1);
Buffer<uint> Text : register(t2);
#define MAX_TEXT 4096

uint Printable(uint c)
{
    return (c >= 32 && c <= 126) ? c : 63; // Unsupported bytes become '?'.
}

float GlyphWidth(uint c, uint2 cell)
{
    // Atlas cells include horizontal padding; advance less than the draw width.
    return cell.x * 0.625f; // 10 reference pixels at scale 1 (16px line height).
}

float Advance(uint c, uint2 cell)
{
    if (c == 13 || c == 10) return 0;
    if (c == 9) return 4 * GlyphWidth(32, cell);
    return GlyphWidth(Printable(c), cell);
}

#ifdef COMPUTE_SHADER
RWStructuredBuffer<float4> Layout : register(u0);

[numthreads(1, 1, 1)]
void main()
{
    uint width, height, count;
    Font.GetDimensions(width, height);
    Text.GetDimensions(count);
    count = min(count, (uint)MAX_TEXT);
    uint2 cell = uint2(width / 16, height / 6);

    // Clear unused entries too: a shorter string must not leave old glyphs.
    for (uint i = 0; i <= MAX_TEXT; ++i) Layout[i] = 0;
    if (cell.x == 0 || cell.y == 0) return;

    uint length = 0;
    while (length < count) {
        if (Text[length] == 0) break;
        ++length;
    }

    uint start = 0;
    float lineY = 0;
    float blockWidth = 0;
    float align = clamp(round(IniParams[99].z), 0.0f, 2.0f) * 0.5f;
    while (start < length) {
        uint end = start;
        float lineWidth = 0;
        while (end < length) {
            if (Text[end] == 10) break;
            lineWidth += Advance(Text[end], cell);
            ++end;
        }
        blockWidth = max(blockWidth, lineWidth);
        float x = -lineWidth * align;
        for (uint k = start; k < end; ++k) {
            uint c = Text[k];
            float advance = Advance(c, cell);
            if (c != 13 && c != 9 && c != 32)
                Layout[k] = float4(x + (advance - cell.x) * 0.5f, lineY, cell.x, cell.y);
            x += advance;
        }
        lineY += cell.y;
        start = end + 1;
    }
    // Extra entry stores the aligned text block bounds.
    Layout[MAX_TEXT] = float4(-blockWidth * align, 0, blockWidth, lineY);
}
#endif

struct VertexOutput {
    float4 position : SV_Position;
    float2 texel : TEXCOORD0;
    nointerpolation uint solid : TEXCOORD1;
};

#ifdef VERTEX_SHADER
StructuredBuffer<float4> Layout : register(t3);
Texture2D<float> ViewportSize : register(t4);

VertexOutput main(uint vertex : SV_VertexID)
{
    VertexOutput output;
    uint width, height;
    Font.GetDimensions(width, height);
    float2 cell = float2(width / 16, height / 6);

#ifdef TEXT_BACKGROUND_PASS
    uint index = MAX_TEXT;
    bool solid = true;
#else
    uint index = vertex / 6;
    bool solid = false;
#endif
    float4 glyph = Layout[index];
    if (solid && glyph.z > 0 && glyph.w > 0) {
        // Compensate for the atlas ink center sitting above/right of the cell center.
        // Reference-pixel offset scales with the font, like the padding below.
        glyph.xy += float2(0.25f, -1.5f) * (cell.y / 16.0f);
        // Padding is in font pixels and scales with the text.
        glyph.xy -= float2(4, 2) * (cell.y / 16.0f);
        glyph.zw += float2(8, 4) * (cell.y / 16.0f);
    }
    output.position = float4(-2, -2, 0, 1);
    output.texel = 0;
    output.solid = solid ? 1u : 0u;
    if (glyph.z <= 0 || glyph.w <= 0) return output;

    uint c = 32;
    if (!solid) c = Printable(Text[index]);
    const float2 corners[6] = {
        float2(0, 0), float2(1, 0), float2(0, 1),
        float2(0, 1), float2(1, 0), float2(1, 1)
    };
    float2 corner = corners[vertex % 6];
    // Scale 1: 16 pixels per line at 1080p, proportional at other resolutions.
    float unitY = max(IniParams[99].w, 0.0f) * 16.0f / (max(cell.y, 1.0f) * 1080.0f);
    uint viewportWidth, viewportHeight;
    ViewportSize.GetDimensions(viewportWidth, viewportHeight);
    if (viewportWidth == 0 || viewportHeight == 0) return output;
    float2 unit = float2(unitY * (float)viewportHeight / (float)viewportWidth, unitY);
    float2 position = IniParams[99].xy + (glyph.xy + corner * glyph.zw) * unit;
    output.position = float4(position * float2(2, -2) + float2(-1, 1), 0, 1);
    output.texel = float2(c % 16, c / 16 - 2) * cell + corner * glyph.zw;
    return output;
}
#endif

#ifdef PIXEL_SHADER
cbuffer TextColor : register(b0)
{
    float4 Color;
}

float4 main(VertexOutput input) : SV_Target0
{
    if (input.solid != 0) return Color;
    float coverage = Font.Load(int3(int2(input.texel), 0));
    return float4(Color.rgb, Color.a * coverage);
}
#endif
