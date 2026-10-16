// HLSL shaders for RCEFShaders
// Foliage Dither - Leaf

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb3 : register(b3)
{
	float4 cb3[15];
}

cbuffer cb2 : register(b2)
{
	float4 cb2[4091];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[27];
}

cbuffer DistanceControls : register(b4)
{
	float FoliageDist;
	float GrassDist;
	float DistCullShadows;
	float _Padding;
};

#define cmp -

void main(
	float4 v0 : SV_Position0,
	float4 v1 : TEXCOORD0,
	float4 v2 : TEXCOORD1,
	float4 v3 : TEXCOORD2,
	float4 v4 : TEXCOORD3,
	nointerpolation uint v5 : TEXCOORD4
)
{
	if (v0.w < FoliageDist) {
		discard;
	}

	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.xy = float2(0.5,0.5) * v0.xy;
	r0.xy = floor(r0.xy);
	r0.x = dot(r0.xy, float2(0.0671105608,0.00583714992));
	r0.x = frac(r0.x);
	r0.x = 52.9829178 * r0.x;
	r0.x = frac(r0.x);
	r0.y = (int)v5.x * 6;
	r0.z = cmp(cb2[r0.y+4].w >= 0);
	r0.z = r0.z ? r0.x : -r0.x;
	r0.y = cb2[r0.y+4].w + -r0.z;
	r0.x = 1 + -r0.x;
	r0.x = min(r0.y, r0.x);
	r0.y = dot(v1.xyz, cb3[10].xyz);
	r0.y = cmp(r0.y >= cb3[14].x);
	r0.y = r0.y ? 1.000000 : 0;
	r0.x = -r0.y * cb3[8].z + r0.x;
	r0.y = t0.SampleBias(s0_s, v2.xy, cb1[26].x).w;
	r0.y = -cb3[3].z + r0.y;
	r0.x = min(r0.x, r0.y);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	return;
}