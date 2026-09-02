// CustomShader for RCEFShaders EFMI mod

Texture3D<float4> t28 : register(t28);

Texture2D<float4> t27 : register(t27);

Texture2D<float4> t26 : register(t26);

Texture2D<float4> t25 : register(t25);

Texture2D<float4> t24 : register(t24);

Texture3D<float4> t23 : register(t23);

Texture3D<float4> t22 : register(t22);

Texture3D<float4> t21 : register(t21);

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_Target0)
{
	float3 r0;
	r0.xy = (uint2)v0.xy;
	r0.z = 0;

	o0.xyz = t27.Load(r0.xyz).xyz;
	o0.w = 1;

	return;
}