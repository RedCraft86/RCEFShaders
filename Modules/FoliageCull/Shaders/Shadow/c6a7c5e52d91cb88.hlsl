// HLSL shaders for RCEFShaders
// Foliage Shadow - Tree Foliage Card Mesh LOD

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb1 : register(b1)
{
	float4 cb1[3];
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
	float4 v2 : TEXCOORD1,
	float4 v3 : TEXCOORD2,
	float4 v4 : TEXCOORD3,
	uint v5 : TEXCOORD4
)
{
	if (DistCullShadows > 0 && v0.w < FoliageDist) {
		discard;
	}

	float4 r0;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = t0.SampleBias(s0_s, v2.xy, cb0[26].x).w;
	r0.x = -cb1[2].y + r0.x;
	r0.x = min(1, r0.x);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	return;
}