// CustomShader for RCEFShaders EFMI mod

Texture2D<float4> t22 : register(t22);

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	out float4 o0 : SV_Target0)
{
	float3 r0;
	r0.xy = (uint2)v0.xy;
	r0.z = 0;

	o0.xyz = t22.Load(r0.xyz).xyz;
	o0.w = 1;

	return;
}
