// CustomShader for RCEFShaders EFMI mod

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
	float4 cb2[4];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[4091];
}

cbuffer cb0 : register(b0)
{
	float4 cb0[27];
}


cbuffer DistCullParams : register(b3)
{
	float MaxDist;
	float3 _pad;
}


#define cmp -

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	float2 w1 : TEXCOORD1,
	float4 v2 : TEXCOORD2,
	float4 v3 : TEXCOORD3,
	nointerpolation uint v4 : TEXCOORD4)
{
	// Near distance culling logic
	if (v0.w < MaxDist)
		discard;


	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = dot(v0.xy, float2(0.0671105608,0.00583714992));
	r0.x = frac(r0.x);
	r0.x = 52.9829178 * r0.x;
	r0.x = frac(r0.x);
	r0.y = (int)v4.x * 6;
	r0.z = cmp(cb1[r0.y+4].w >= 0);
	r0.z = r0.z ? r0.x : -r0.x;
	r0.y = cb1[r0.y+4].w + -r0.z;
	r0.z = 1 + -r0.x;
	r0.y = min(r0.y, r0.z);
	r0.y = cmp(r0.y < 0);
	if (r0.y != 0) discard;
	r0.y = t0.SampleBias(s0_s, v1.xy, cb0[26].x).w;
	r0.z = cmp(w1.y >= 0);
	r0.x = r0.z ? r0.x : -r0.x;
	r0.x = w1.y + -r0.x;
	r0.x = cmp(r0.x >= 0);
	r0.x = r0.x ? 1.000000 : 0;
	r0.x = r0.y * r0.x;
	r0.x = cmp(r0.x < cb2[3].z);
	if (r0.x != 0) discard;
	return;
}
