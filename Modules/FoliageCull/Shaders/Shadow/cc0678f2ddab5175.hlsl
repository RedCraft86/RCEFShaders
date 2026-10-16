// HLSL shaders for RCEFShaders
// Foliage Shadow - Grass / Grass Card Mesh LOD

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb2 : register(b2)
{
	float4 cb2[4];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[4085];
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
	nointerpolation uint v6 : TEXCOORD6
)
{
	if (DistCullShadows > 0 && v0.w < GrassDist) {
		discard;
	}

	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = (uint)v6.x << 4;
	r0.y = max(cb1[r0.x+4].y, cb1[r0.x+4].z);
	r0.y = 1 + -r0.y;
	r0.z = cmp(0 < w2.x);
	r0.z = r0.z ? w2.y : 1;
	r0.x = min(cb1[r0.x+4].x, r0.z);
	r0.z = min(r0.y, r0.x);
	r0.z = cmp(r0.z < 1);
	if (r0.z != 0) {
		r0.z = max(cb2[3].y, 1);
		r0.zw = v0.xy * r0.zz;
		r0.zw = floor(r0.zw);
		r0.z = dot(r0.zw, float2(0.0671105608,0.00583714992));
		r0.z = frac(r0.z);
		r0.z = 52.9829178 * r0.z;
		r0.z = frac(r0.z);
		r0.w = cmp(r0.x >= 0);
		r0.w = r0.w ? r0.z : -r0.z;
		r0.xy = r0.xy + -r0.wz;
		r0.x = min(r0.x, r0.y);
	} else {
		r0.x = 1;
	}
	r0.y = t0.SampleBias(s0_s, v2.xy, cb0[26].x).w;
	r0.y = -cb2[1].w + r0.y;
	r0.x = min(r0.x, r0.y);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	return;
}