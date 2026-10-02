// Custom Shader for RCEFShaders EFMI mod

#ifdef VERTEX_SHADER
Texture1D<float4> IniParams : register(t120);
#define Position (IniParams[99].xy) // Normalized viewport coords from (0, 0) top-left to (1, 1) bottom-right
#define Size     (IniParams[99].zw) // Full width and height as fractions of the viewport ranging 0 to 1

void main(
	uint vertex : SV_VertexID,
	out float4 outPos : SV_Position0,
	out float2 outUV : TEXCOORD1
)
{
	outUV = float2(vertex & 1u, (vertex >> 1u) & 1u);
	outUV.y = 1.0f - outUV.y;

	const float2 viewportPos = Position + outUV * Size;
	outPos = float4(viewportPos * float2(2.0f, -2.0f) + float2(-1.0f, 1.0f), 0.0f, 1.0f);
}
#endif

#ifdef PIXEL_SHADER
Texture2D<float4> Image : register(t1);
cbuffer ColorParams : register(b0)
{
	float4 Tint;
}

void main(
	float4 pos : SV_Position0,
	float2 uv : TEXCOORD1,
	out float4 outColor : SV_Target0
)
{
	uint width, height;
	Image.GetDimensions(width, height);
	if (!width || !height) {
		outColor = Tint;
		return;
	}

	const int2 imgUV = min(
		int2(saturate(uv) * float2(width, height)),
		int2(width, height) - 1
	);

	outColor = Image.Load(int3(imgUV, 0)) * Tint;
}
#endif