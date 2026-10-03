// HLSL shaders for RCEFShaders

/**
 * Usage Example:
 *	[ResourceDataExample]
 *	type = Buffer
 *	data = R32_FLOAT  0.2   0.2   0.6    0.6
 *	                 PosX  PosY  SizeX  SizeY
 *
 *	[ResourceColorExample]
 *	type = Buffer
 *	data = R32_FLOAT 1 1 1 1
 *	                (R G B A) [0..1]
 *
 *	[ResourceImageExample]
 *	filename = path/to/image.png
 *
 *	[CustomShaderDrawTest]
 *	vs = Shaders/Draw2D.hlsl
 *	ps = Shaders/Draw2D.hlsl
 *	cs = null
 *	ds = null
 *	gs = null
 *	hs = null
 *	cull = none
 *	topology = triangle_strip
 *	blend = ADD SRC_ALPHA INV_SRC_ALPHA
 *	o0 = set_viewport no_view_cache bb
 *
 * Data can be provided with IniParams like this:
 *	x99 = X Position (left...right) [0..1]
 *	y99 = Y Position (top...bottom) [0..1]
 *	z99 = Width of the shape as fractions of the viewport [0..1]
 *	w99 = Height of the shape as fractions of the viewport [0..1]
 * Or with a buffer:
 *	vs-cb0 = Buffer containing position and size data
 *
 *	ps-cb0 = Color to tint the image with or fill if no image is provided
 *	ps-t1 = (Optional) Image to draw
 *	draw = 4, 0
 */

#ifdef VERTEX_SHADER
Texture1D<float4> IniParams : register(t120);

cbuffer DrawData : register(b0)
{
	float2 DrawPos;
	float2 DrawSize;
}

static const uint DRAW_PARAMS_INDEX = 99;

float2 GetDrawPos()
{
	return (DrawSize.x > 0 && DrawSize.y > 0) ? DrawPos : IniParams[DRAW_PARAMS_INDEX].xy;
}

float2 GetDrawSize()
{
	return (DrawSize.x > 0 && DrawSize.y > 0) ? DrawSize : IniParams[DRAW_PARAMS_INDEX].zw;
}

float4 main(
	uint VertexIndex : SV_VertexID,
	out float2 OutUV : TEXCOORD0
) : SV_Position
{
	// Triangle strip corners: bottom-left, bottom-right, top-left, top-right.
	OutUV = float2(VertexIndex & 1u, (VertexIndex >> 1u) & 1u);
	OutUV.y = 1.0f - OutUV.y;

	const float2 ScreenPosition = GetDrawPos() + OutUV * GetDrawSize();
	return float4(ScreenPosition * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
}
#endif

#ifdef PIXEL_SHADER
Texture2D<float4> Image : register(t1);

cbuffer ImageTint : register(b0)
{
	float4 TintColor;
}

float4 main(
	float4 Position : SV_Position,
	float2 UV : TEXCOORD0
) : SV_Target0
{
	uint ImageWidth, ImageHeight;
	Image.GetDimensions(ImageWidth, ImageHeight);
	// An unbound image draws a solid tinted rectangle.
	if (ImageWidth == 0 || ImageHeight == 0) {
		return TintColor;
	}

	// Clamp to valid texels, including the UV = 1 edge.
	const int2 ImageTexel = min(
		int2(saturate(UV) * float2(ImageWidth, ImageHeight)),
		int2(ImageWidth, ImageHeight) - 1
	);

	return Image.Load(int3(ImageTexel, 0)) * TintColor;
}
#endif