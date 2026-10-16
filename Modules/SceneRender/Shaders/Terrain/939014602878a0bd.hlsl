// HLSL shaders for RCEFShaders
// Terrain Deferred

Texture2D<float4> t30 : register(t30);

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	out float4 o0 : SV_Target0
)
{
	o0 = float4(t30.Load(int3((uint2)v0.xy, 0)).xyz, 1);
}
