// CustomShader for RCEFShaders EFMI mod

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb1 : register(b1)
{
	float4 cb1[4];
}

cbuffer cb0 : register(b0)
{
	float4 cb0[27];
}


cbuffer DistCullParams : register(b4)
{
	float MaxDist;
	float3 _pad;
}


#define cmp -
Texture1D<float4> IniParams : register(t120);

void main(
	float4 v0 : SV_Position0,
	float4 v1 : TEXCOORD0,
	float4 v2 : TEXCOORD1,
	float4 v3 : TEXCOORD2,
	uint v4 : TEXCOORD3)
{
	// Near distance culling logic
	if (v0.w < IniParams[186].x)
		discard;


	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = t0.SampleBias(s0_s, v1.xy, cb0[26].x).w;
	r0.x = cmp(r0.x < cb1[3].z);
	if (r0.x != 0) discard;
	return;
}
