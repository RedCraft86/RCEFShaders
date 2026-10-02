// Custom Shader for RCEFShaders EFMI mod

Texture1D<float4> IniParams : register(t120);
Texture2D<float> Font : register(t1);
Buffer<uint> Text : register(t2);

#define MAX_TEXT 4096
#define Position (IniParams[99].xy) // Horizontal alignment point and vertical point at to. Normalized 0..1
#define HAlign   (IniParams[99].z)  // Horizontal alignment area: 0 left, 1 center, 2 right.
#define Size     (IniParams[99].w)  // Scale multiplier: 1 gives a line height of 16/1080 of the viewport

uint Printable(uint c)
{
	return (c >= 32 && c <= 126) ? c : 63; // Unsupported bytes become '?'.
}

float GlyphWidth(uint c, uint2 cell)
{
	// Atlas cells include horizontal padding; advance less than the draw width.
	return cell.x * 0.75; // 12 reference pixels at scale 1 (16px line height).
}

float Advance(uint c, uint2 cell)
{
	if (c == 13 || c == 10) {
		return 0;
	}

	if (c == 9) {
		return 4 * GlyphWidth(32, cell);
	}

	return GlyphWidth(Printable(c), cell);
}

#ifdef COMPUTE_SHADER
RWStructuredBuffer<float4> Layout : register(u0);

[numthreads(1, 1, 1)]
void main()
{
	uint width, height;
	Font.GetDimensions(width, height);
	uint2 cell = uint2(width / 16, height / 6);

	uint count;
	Text.GetDimensions(count);
	count = min(count, (uint)MAX_TEXT);

	// Clear old layout
	for (uint i = 0; i <= MAX_TEXT; i++) {
		Layout[i] = 0;
	}

	if (cell.x == 0 || cell.y == 0) {
		return;
	}

	uint length = 0;
	while (length < count) {
		if (Text[length] == 0) {
			break;
		}

		length++;
	}

	uint start = 0;
	float lineY = 0;
	float blockWidth = 0;
	float align = clamp(round(HAlign), 0.0f, 2.0f) * 0.5f;
	while (start < length) {
		uint end = start;
		float lineWidth = 0;
		while (end < length) {
			if (Text[end] == 10) {
				break;
			}

			lineWidth += Advance(Text[end], cell);
			end++;
		}

		blockWidth = max(blockWidth, lineWidth);
		float x = -lineWidth * align;

		for (uint k = start; k < end; k++) {
			uint c = Text[k];
			float advance = Advance(c, cell);
			if (c != 13 && c != 9 && c != 32) {
				Layout[k] = float4(x + (advance - cell.x) * 0.5f, lineY, cell.x, cell.y);
			}

			x += advance;
		}

		lineY += cell.y;
		start = end + 1;
	}

	// Extra entry stores the aligned text block bounds.
	Layout[MAX_TEXT] = float4(-blockWidth * align, 0, blockWidth, lineY);
}
#endif

#ifdef VERTEX_SHADER
StructuredBuffer<float4> Layout : register(t3);
Texture2D<float> ViewportSize : register(t4);

void main(
	uint vertex : SV_VertexID,
	out float4 outPos : SV_Position,
	out float2 outTexel : TEXCOORD0
)
{
	uint width, height;
	Font.GetDimensions(width, height);
	float2 cell = float2(width / 16, height / 6);

	uint index = vertex / 6;
	float4 glyph = Layout[index];

	outTexel = 0;
	outPos = float4(-2, -2, 0, 1);
	if (glyph.z <= 0 || glyph.w <= 0) {
		return;
	}

	uint c = Printable(Text[index]);

	const float2 corners[6] = {
		float2(0, 0), float2(1, 0), float2(0, 1),
		float2(0, 1), float2(1, 0), float2(1, 1)
	};

	float2 corner = corners[vertex % 6];

	// Scale 1: 16 pixels per line at 1080p, proportional at other resolutions.
	float unitY = max(Size, 0.0f) * 16.0f / (max(cell.y, 1.0f) * 1080.0f);

	uint resWidth, resHeight;
	ViewportSize.GetDimensions(resWidth, resHeight);
	if (resWidth == 0 || resHeight == 0) {
		return;
	}

	float2 unit = float2(unitY * (float)resHeight / (float)resWidth, unitY);
	float2 pos = Position + (glyph.xy + corner * glyph.zw) * unit;
	outPos = float4(pos * float2(2, -2) + float2(-1, 1), 0, 1);
	outTexel = float2(c % 16, c / 16 - 2) * cell + corner * glyph.zw;
}
#endif

#ifdef PIXEL_SHADER
cbuffer BGColorParams : register(b1)
{
	float4 BGColor;
}

cbuffer TextColorParams : register(b0)
{
	float4 TextColor;
}

void main(
	float4 pos : SV_Position,
	float2 texel : TEXCOORD0,
	out float4 outColor : SV_Target0
)
{
	uint fontWidth, fontHeight;
	Font.GetDimensions(fontWidth, fontHeight);

	float cellHeight = fontHeight / 6;
	float rowTop = floor(texel.y / cellHeight) * cellHeight;

	// Sample higher in the atlas to move the visible text down.
	float2 sampleTexel = texel;
	sampleTexel.y = clamp(
		texel.y - cellHeight / 16.0f,
		rowTop,
		rowTop + cellHeight - 1
	);

	float coverage = Font.Load(int3(int2(sampleTexel), 0));

	if (BGColor.a > 0) {
		coverage = saturate(coverage * 1.25f);
	}

	outColor = lerp(BGColor, TextColor, coverage);
}
#endif