// HLSL shaders for RCEFShaders
// Foliage Shadow - Grass Card Mesh LOD

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
	float2 v2 : TEXCOORD1,
	float2 w2 : TEXCOORD2,
	float4 v3 : TEXCOORD3,
	float4 v4 : TEXCOORD4,
	float4 v5 : TEXCOORD5,
	float4 v6 : TEXCOORD6,
	nointerpolation uint v7 : TEXCOORD7
)
{
	if (DistCullShadows > 0 && v0.w < GrassDist) {
		discard;
	}

	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = (int)v7.x * 6;
	r0.y = cmp(0 < w2.x);
	r0.y = r0.y ? w2.y : 1;
	r0.x = min(cb1[r0.x+4].w, r0.y);
	r0.y = min(1, r0.x);
	r0.y = cmp(r0.y < 1);
	if (r0.y != 0) {
		r0.y = max(cb2[3].y, 1);
		r0.yz = v0.xy * r0.yy;
		r0.yz = floor(r0.yz);
		r0.y = dot(r0.yz, float2(0.0671105608,0.00583714992));
		r0.y = frac(r0.y);
		r0.y = 52.9829178 * r0.y;
		r0.y = frac(r0.y);
		r0.z = cmp(r0.x >= 0);
		r0.z = r0.z ? r0.y : -r0.y;
		r0.x = r0.x + -r0.z;
		r0.y = 1 + -r0.y;
		r0.x = min(r0.x, r0.y);
	} else {
		r0.x = 1;
	}
	r0.y = t0.SampleBias(s0_s, v2.xy, cb0[26].x).w;
	r0.y = r0.y * v3.y + -cb2[1].w;
	r0.x = min(r0.x, r0.y);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	return;
}