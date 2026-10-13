// HLSL shaders for RCEFShaders
// Foliage Mask

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
  float4 v5 : TEXCOORD4,
  nointerpolation uint v6 : TEXCOORD5)
{
	// Near distance culling logic
	if (v0.w < MaxDist)
		discard;


  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = dot(v0.xy, float2(0.0671105608,0.00583714992));
  r0.x = frac(r0.x);
  r0.x = 52.9829178 * r0.x;
  r0.x = frac(r0.x);
  r0.y = (int)v6.x * 6;
  r0.z = cmp(cb2[r0.y+4].w >= 0);
  r0.z = r0.z ? r0.x : -r0.x;
  r0.y = cb2[r0.y+4].w + -r0.z;
  r0.x = 1 + -r0.x;
  r0.x = min(r0.y, r0.x);
  r0.x = cmp(r0.x < 0);
  if (r0.x != 0) discard;
  r0.x = t0.SampleBias(s0_s, v1.xy, cb1[26].x).w;
  r0.y = cb3[5].x + -1;
  r0.z = -cb3[5].x + 1;
  r1.x = cb0[0].z;
  r1.y = cb0[1].z;
  r1.z = cb0[2].z;
  r0.w = dot(r1.xyz, r1.xyz);
  r0.w = max(1.17549435e-38, r0.w);
  r0.w = rsqrt(r0.w);
  r1.xyz = r1.xyz * r0.www;
  r0.w = dot(r1.xyz, v2.xyz);
  r0.w = -cb3[4].w + abs(r0.w);
  r0.z = r0.z + -r0.y;
  r0.y = r0.w + -r0.y;
  r0.z = 1 / r0.z;
  r0.y = saturate(r0.y * r0.z);
  r0.z = r0.y * -2 + 3;
  r0.y = r0.y * r0.y;
  r0.y = r0.z * r0.y;
  r0.z = cb3[2].x + -1.00999999;
  r0.y = r0.y * r0.z + 1.00999999;
  r0.x = cmp(r0.x < r0.y);
  if (r0.x != 0) discard;
  return;
}
