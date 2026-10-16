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
	float4 cb2[4085];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[178];
}

cbuffer cb0 : register(b0)
{
	float4 cb0[45];
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
	nointerpolation uint v5 : TEXCOORD5
)
{
	if (v0.w < FoliageDist) {
		discard;
	}

	float4 r0,r1,r2;
	uint4 bitmask, uiDest;
	float4 fDest;

	r0.x = (uint)v5.x << 4;
	r0.y = cb2[r0.x+4].z + 2;
	r0.y = cmp(abs(r0.y) < 0.00999999978);
	if (r0.y != 0) {
		r0.yzw = -cb0[44].xyz + v1.xyz;
		r1.xyz = cb1[177].xyz + -cb0[44].xyz;
		r1.w = dot(r0.yzw, r1.xyz);
		r2.x = dot(r1.xyz, r1.xyz);
		r2.x = max(9.99999975e-005, r2.x);
		r1.w = saturate(r1.w / r2.x);
		r0.yzw = -r1.xyz * r1.www + r0.yzw;
		r0.y = dot(r0.yzw, r0.yzw);
		r0.y = sqrt(r0.y);
		r0.y = cb1[176].x + -r0.y;
		r0.y = max(0, r0.y);
		r0.z = max(cb1[176].y, 9.99999975e-005);
		r0.y = r0.y / r0.z;
		r0.y = 1 + -r0.y;
		r0.y = max(0, r0.y);
	} else {
		r0.y = 1;
	}
	r0.z = max(cb2[r0.x+4].y, cb2[r0.x+4].z);
	r0.z = 1 + -r0.z;
	r0.y = min(r0.y, r0.z);
	r0.z = dot(cb2[r0.x+3].xyz, cb2[r0.x+3].xyz);
	r0.z = sqrt(r0.z);
	r0.z = cb3[4].y * r0.z;
	r0.w = cmp(0.999938965 >= r0.y);
	r0.w = r0.w ? 1.000000 : 0;
	r0.zw = r0.zz * r0.ww + v0.xy;
	r0.zw = float2(0.5,0.5) * r0.zw;
	r0.zw = floor(r0.zw);
	r0.z = dot(r0.zw, float2(0.0671105608,0.00583714992));
	r0.z = frac(r0.z);
	r0.z = 52.9829178 * r0.z;
	r0.w = dot(v0.xy, float2(0.0671105608,0.00583714992));
	r0.zw = frac(r0.zw);
	r0.w = 52.9829178 * r0.w;
	r0.w = frac(r0.w);
	r1.x = cmp(cb2[r0.x+4].x >= 0);
	r1.x = r1.x ? r0.z : -r0.z;
	r0.x = cb2[r0.x+4].x + -r1.x;
	r0.y = r0.y + -r0.z;
	r0.x = min(r0.x, r0.y);
	r0.y = dot(v1.xyz, cb3[10].xyz);
	r0.y = cmp(r0.y >= cb3[14].x);
	r0.y = r0.y ? 1.000000 : 0;
	r0.x = -r0.y * cb3[8].z + r0.x;
	r0.y = t0.SampleBias(s0_s, v2.xy, cb1[26].x).w;
	r0.z = cmp(w2.y >= 0);
	r0.z = r0.z ? r0.w : -r0.w;
	r0.z = w2.y + -r0.z;
	r0.z = cmp(r0.z >= 0);
	r0.z = r0.z ? 1.000000 : 0;
	r0.y = r0.y * r0.z + -cb3[3].z;
	r0.x = min(r0.x, r0.y);
	r0.x = cmp(r0.x < 0);
	if (r0.x != 0) discard;
	return;
}