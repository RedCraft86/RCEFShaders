// HLSL shaders for RCEFShaders
// Foliage Mask

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
	float4 cb2[2];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[4091];
}

cbuffer cb0 : register(b0)
{
	float4 cb0[27];
}


cbuffer DistCullParams : register(b4)
{
	float _pad1;
	float MaxDist;
	float2 _pad2;
}


#define cmp -

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	float2 w1 : TEXCOORD1,
	float4 v2 : TEXCOORD2,
	float4 v3 : TEXCOORD3,
	float4 v4 : TEXCOORD4,
	nointerpolation uint v5 : TEXCOORD5)
{
	// Near distance culling logic
	if (v0.w < MaxDist)
		discard;


	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = (int)v5.x * 6;
	r0.y = cmp(0 < w1.x);
	r0.y = r0.y ? w1.y : 1;
	r0.x = min(cb1[r0.x+4].w, r0.y);
	r0.y = dot(v0.xy, float2(0.0671105608,0.00583714992));
	r0.y = frac(r0.y);
	r0.y = 52.9829178 * r0.y;
	r0.y = frac(r0.y);
	r0.z = cmp(r0.x >= 0);
	r0.z = r0.z ? r0.y : -r0.y;
	r0.x = r0.x + -r0.z;
	r0.y = 1 + -r0.y;
	r0.x = min(r0.x, r0.y);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	r0.x = t0.SampleBias(s0_s, v1.xy, cb0[26].x).w;
	r0.x = cmp(r0.x < cb2[1].w);
	if (r0.x != 0) discard;
	return;
}
