// Custom Shader for RCEFShaders EFMI mod

#ifdef VERTEX_SHADER
Texture1D<float4> IniParams : register(t120);
#define Position (IniParams[99].xy) // Top-left corner in normalized viewport coordinates.
#define Size (IniParams[99].zw) // Full width and height as fractions of the viewport.

void main(
	uint Vertex : SV_VertexID,
	out float4 OutPos : SV_Position0,
	out float2 OutUV : TEXCOORD1)
{
	OutUV = float2(Vertex & 1u, (Vertex >> 1u) & 1u);

	float2 ViewportPos = Position + float2(OutUV.x, 1.0f - OutUV.y) * Size;
	OutPos = float4(ViewportPos * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
}
#endif

#ifdef PIXEL_SHADER
Texture2D<float4> Image : register(t1);

cbuffer TintParams : register(b0)
{
	float4 ImageTint; // RGBA tint; white preserves the original image.
}

void main(
	float4 Pos : SV_Position0,
	float2 UV : TEXCOORD1,
	out float4 OutColor : SV_Target0)
{
	uint Width, Height;
	Image.GetDimensions(Width, Height);
	if (!Width || !Height) {
		OutColor = ImageTint;
		return;
	}

	UV.y = 1 - UV.y;
	const int2 ImageUV = min(
		int2(saturate(UV) * float2(Width, Height)),
		int2(Width, Height) - 1
	);

	OutColor = Image.Load(int3(ImageUV, 0)) * ImageTint;
}
#endif
