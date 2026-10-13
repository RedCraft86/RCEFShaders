// HLSL shaders for RCEFShaders

Texture1D<float4> IniParams : register(t120);
Texture2D<float> Font : register(t1);
Buffer<uint> Text : register(t2);

cbuffer TextData : register(b0)
{
	float2 TextPos;
	float TextAlign;
	float TextSize;
}

static const uint TEXT_PARAMS_INDEX = 99;

static const uint ASCII_NULL = 0;
static const uint ASCII_TAB = 9;
static const uint ASCII_LINE_FEED = 10;
static const uint ASCII_CARRIAGE_RETURN = 13;
static const uint ASCII_SPACE = 32;
static const uint ASCII_PRINTABLE_LAST = 126;
static const uint ASCII_QUESTION_MARK = 63;

static const uint ATLAS_ROWS = 6;
static const uint ATLAS_COLS = 16;
static const uint VERTICES_PER_GLYPH = 6;

static const float REF_LINE_HEIGHT = 16.0f;
static const float REF_VIEWPORT_HEIGHT = 1080.0f;
static const float FONT_X_OFFSET_RATIO = 2.0f / 16.0f;
static const float FONT_Y_OFFSET_RATIO = 1.0f / 16.0f;
static const float BACKGROUND_COVERAGE_BOOST = 1.25f;

// Must match ResourceLayout: glyph rectangles (x, y, width, height), then block bounds.
static const uint LAYOUT_CAPACITY = 4096;
static const uint BLOCK_BOUNDS_INDEX = LAYOUT_CAPACITY - 1;

float2 GetTextPosition()
{
	return TextSize > 0 ? TextPos : IniParams[TEXT_PARAMS_INDEX].xy;
}

float GetTextHAlign()
{
	return TextSize > 0 ? TextAlign : IniParams[TEXT_PARAMS_INDEX].z;
}

float GetTextSize()
{
	return TextSize > 0 ? TextSize : IniParams[TEXT_PARAMS_INDEX].w;
}

uint Printable(uint Character)
{
	// Replace unknowns with '?'
	return (Character >= ASCII_SPACE && Character <= ASCII_PRINTABLE_LAST)
		? Character : ASCII_QUESTION_MARK;
}

float GlyphWidth(float2 CellSize)
{
	// Atlas cells include padding; advance less than the drawn width.
	// 0.625 * 16 -> 10 reference pixels at scale 1 (16px line height).
	return CellSize.x * 0.625f;
}

float Advance(uint Character, float2 CellSize)
{
	if (Character == ASCII_CARRIAGE_RETURN || Character == ASCII_LINE_FEED) {
		return 0.0f;
	}

	return GlyphWidth(CellSize) * ((Character == ASCII_TAB) ? 4 : 1);
}

#ifdef COMPUTE_SHADER
RWStructuredBuffer<float4> Layout : register(u0);

[numthreads(1, 1, 1)]
void main()
{
	uint FontWidth, FontHeight;
	Font.GetDimensions(FontWidth, FontHeight);
	float2 CellSize = float2(FontWidth / ATLAS_COLS, FontHeight / ATLAS_ROWS);

	uint CharacterCount;
	Text.GetDimensions(CharacterCount);
	CharacterCount = min(CharacterCount, BLOCK_BOUNDS_INDEX);

	// Clear stale glyphs when the text becomes shorter.
	for (uint LayoutIndex = 0; LayoutIndex < LAYOUT_CAPACITY; LayoutIndex++) {
		Layout[LayoutIndex] = 0;
	}

	if (CellSize.x == 0 || CellSize.y == 0) {
		return;
	}

	uint TextLength = 0;
	while (TextLength < CharacterCount) {
		if (Text[TextLength] == ASCII_NULL) {
			break;
		}

		TextLength++;
	}

	uint LineStart = 0;
	float LineY = 0.0f;
	float BlockWidth = 0.0f;
	float AlignmentFactor = clamp(round(GetTextHAlign()), 0.0f, 2.0f) / 2.0f;
	while (LineStart < TextLength) {
		uint LineEnd = LineStart;
		float LineWidth = 0.0f;
		while (LineEnd < TextLength) {
			if (Text[LineEnd] == ASCII_LINE_FEED) {
				break;
			}

			LineWidth += Advance(Text[LineEnd], CellSize);
			LineEnd++;
		}

		BlockWidth = max(BlockWidth, LineWidth);
		float PenX = -LineWidth * AlignmentFactor;

		for (uint CharacterIndex = LineStart; CharacterIndex < LineEnd; CharacterIndex++) {
			uint Character = Text[CharacterIndex];
			float CharacterAdvance = Advance(Character, CellSize);
			if (Character != ASCII_CARRIAGE_RETURN && Character != ASCII_TAB) {
				Layout[CharacterIndex] = float4(
					PenX + (CharacterAdvance - CellSize.x) * 0.5f,
					LineY, CellSize.x, CellSize.y
				);
			}

			PenX += CharacterAdvance;
		}

		LineY += CellSize.y;
		LineStart = LineEnd + 1;
	}

	Layout[BLOCK_BOUNDS_INDEX] = float4(-BlockWidth * AlignmentFactor, 0, BlockWidth, LineY);
}
#endif

#ifdef VERTEX_SHADER
StructuredBuffer<float4> Layout : register(t3);
Texture2D<float> ViewportSize : register(t4);

void main(
	uint VertexIndex : SV_VertexID,
	out float4 OutPosition : SV_Position,
	out float2 OutTexel : TEXCOORD0
)
{
	OutTexel = 0;
	OutPosition = float4(-2, -2, 0, 1);

	uint CharacterIndex = VertexIndex / VERTICES_PER_GLYPH;
	uint CharacterCount;
	Text.GetDimensions(CharacterCount);
	if (CharacterIndex >= min(CharacterCount, BLOCK_BOUNDS_INDEX)) {
		return;
	}

	float4 Glyph = Layout[CharacterIndex];
	if (Glyph.z <= 0 || Glyph.w <= 0) {
		return;
	}

	uint FontWidth, FontHeight;
	Font.GetDimensions(FontWidth, FontHeight);
	float2 CellSize = float2(FontWidth / ATLAS_COLS, FontHeight / ATLAS_ROWS);
	uint Character = Printable(Text[CharacterIndex]);

	const float2 Corners[VERTICES_PER_GLYPH] = {
		float2(0, 0), float2(1, 0), float2(0, 1),
		float2(0, 1), float2(1, 0), float2(1, 1)
	};
	float2 Corner = Corners[VertexIndex % VERTICES_PER_GLYPH];
	float VerticalUnit = (max(GetTextSize(), 0.0f) * REF_LINE_HEIGHT)
		/ (max(CellSize.y, 1.0f) * REF_VIEWPORT_HEIGHT);

	uint ViewportWidth, ViewportHeight;
	ViewportSize.GetDimensions(ViewportWidth, ViewportHeight);
	if (ViewportWidth == 0 || ViewportHeight == 0) {
		return;
	}

	// Convert atlas pixels to viewport fractions while preserving glyph proportions.
	float2 ViewportUnits = float2(VerticalUnit * (float)ViewportHeight / (float)ViewportWidth, VerticalUnit);
	float2 ScreenPosition = GetTextPosition() + (Glyph.xy + Corner * Glyph.zw) * ViewportUnits;
	// Printable ASCII starts at the atlas row containing space.
	OutTexel = float2(Character % ATLAS_COLS, (Character / ATLAS_COLS) - ASCII_SPACE / ATLAS_COLS)
		* CellSize + Corner * Glyph.zw;
	OutPosition = float4(ScreenPosition * float2(2, -2) + float2(-1, 1), 0, 1);
}
#endif

#ifdef PIXEL_SHADER
cbuffer BackgroundColor : register(b1)
{
	float4 BGColor;
}

cbuffer TextColor : register(b2)
{
	float4 Color;
}

float4 main(
	float4 Position : SV_Position,
	float2 Texel : TEXCOORD0
) : SV_Target0
{
	uint FontWidth, FontHeight;
	Font.GetDimensions(FontWidth, FontHeight);

	float CellWidth = FontWidth / (float)ATLAS_COLS;
	float CellHeight = FontHeight / (float)ATLAS_ROWS;
	float ColumnLeft = floor(Texel.x / CellWidth) * CellWidth;
	float RowTop = floor(Texel.y / CellHeight) * CellHeight;
	// Offset sampling right and up while staying within the current atlas cell.
	float2 FontTexel = float2(
		clamp(
			Texel.x + CellWidth * FONT_X_OFFSET_RATIO,
			ColumnLeft, ColumnLeft + CellWidth - 1.0f
		),
		clamp(
			Texel.y - CellHeight * FONT_Y_OFFSET_RATIO,
			RowTop, RowTop + CellHeight - 1.0f
		)
	);

	float Coverage = Font.Load(int3(FontTexel, 0));
	if (BGColor.a > 0) {
		Coverage = saturate(Coverage * BACKGROUND_COVERAGE_BOOST);
	}

	return lerp(BGColor, Color, Coverage);
}
#endif