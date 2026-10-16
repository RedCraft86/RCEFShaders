// HLSL shaders for RCEFShaders
// Foliage Mask - Tree Foliage Card Mesh LOD

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb3 : register(b3)
{
	float4 cb3[6];
}

cbuffer cb2 : register(b2)
{
	float4 cb2[4091];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[27];
}

cbuffer cb0 : register(b0)
{
	float4 cb0[3];
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
	float4 v5 : TEXCOORD4,
	nointerpolation uint v6 : TEXCOORD5
)
{
	if (v0.w < FoliageDist) {
		discard;
	}

	float4 r0,r1;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.xy = float2(0.5,0.5) * v0.xy;
	r0.xy = floor(r0.xy);
	r0.x = dot(r0.xy, float2(0.0671105608,0.00583714992));
	r0.x = frac(r0.x);
	r0.x = 52.9829178 * r0.x;
	r0.x = frac(r0.x);
	r0.y = (int)v6.x * 6;
	r0.z = cmp(cb2[r0.y+4].w >= 0);
	r0.z = r0.z ? r0.x : -r0.x;
	r0.y = cb2[r0.y+4].w + -r0.z;
	r0.x = 1 + -r0.x;
	r0.x = min(r0.y, r0.x);
	r0.y = t0.SampleBias(s0_s, v1.xy, cb1[26].x).w;
	r0.z = cb3[5].x + -1;
	r0.w = -cb3[5].x + 1;
	r1.x = cb0[0].z;
	r1.y = cb0[1].z;
	r1.z = cb0[2].z;
	r1.w = dot(r1.xyz, r1.xyz);
	r1.w = max(1.17549435e-38, r1.w);
	r1.w = rsqrt(r1.w);
	r1.xyz = r1.xyz * r1.www;
	r1.x = dot(r1.xyz, v2.xyz);
	r1.x = -cb3[4].w + abs(r1.x);
	r0.w = r0.w + -r0.z;
	r0.z = r1.x + -r0.z;
	r0.w = 1 / r0.w;
	r0.z = saturate(r0.z * r0.w);
	r0.w = r0.z * -2 + 3;
	r0.z = r0.z * r0.z;
	r0.z = r0.w * r0.z;
	r0.w = cb3[2].x + -1.00999999;
	r0.z = r0.z * r0.w + 1.00999999;
	r0.y = r0.y + -r0.z;
	r0.x = min(r0.x, r0.y);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	return;
}
