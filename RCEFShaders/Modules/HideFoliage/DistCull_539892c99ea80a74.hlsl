// Custom Shader for RCEFShaders EFMI mod

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
	float4 cb2[15];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[4085];
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

void main(
	float4 v0 : SV_Position0,
	float4 v1 : TEXCOORD0,
	float4 v2 : TEXCOORD1,
	float4 v3 : TEXCOORD2,
	float4 v4 : TEXCOORD3,
	nointerpolation uint v5 : TEXCOORD4)
{
	// Near distance culling logic
	if (v0.w < MaxDist)
		discard;


	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = (uint)v5.x << 4;
	r0.y = max(cb1[r0.x+4].y, cb1[r0.x+4].z);
	r0.y = 1 + -r0.y;
	r0.z = dot(cb1[r0.x+3].xyz, cb1[r0.x+3].xyz);
	r0.z = sqrt(r0.z);
	r0.z = cb2[4].y * r0.z;
	r0.w = cmp(0.999938965 >= r0.y);
	r0.w = r0.w ? 1.000000 : 0;
	r0.zw = r0.zz * r0.ww + v0.xy;
	r0.z = dot(r0.zw, float2(0.0671105608,0.00583714992));
	r0.z = frac(r0.z);
	r0.z = 52.9829178 * r0.z;
	r0.z = frac(r0.z);
	r0.w = cmp(cb1[r0.x+4].x >= 0);
	r0.w = r0.w ? r0.z : -r0.z;
	r0.x = cb1[r0.x+4].x + -r0.w;
	r0.y = r0.y + -r0.z;
	r0.x = min(r0.x, r0.y);
	r0.y = dot(v1.xyz, cb2[10].xyz);
	r0.y = cmp(r0.y >= cb2[14].x);
	r0.y = r0.y ? 1.000000 : 0;
	r0.x = -r0.y * cb2[8].z + r0.x;
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	r0.x = t0.SampleBias(s0_s, v2.xy, cb0[26].x).w;
	r0.x = cmp(r0.x < cb2[3].z);
	if (r0.x != 0) discard;
	return;
}
