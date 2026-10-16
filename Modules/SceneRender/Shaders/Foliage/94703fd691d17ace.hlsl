// HLSL shaders for RCEFShaders
// Foliage Deferred

Texture2D<float4> t27 : register(t27);

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	out float4 o0 : SV_Target0
)
{
	o0 = float4(t27.Load(int3((uint2)v0.xy, 0)).xyz, 1);
}
