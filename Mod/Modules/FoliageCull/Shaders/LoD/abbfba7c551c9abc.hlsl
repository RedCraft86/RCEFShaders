// HLSL shaders for RCEFShaders
// Foliage LoD

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb3 : register(b3)
{
  float4 cb3[14];
}

cbuffer cb2 : register(b2)
{
  float4 cb2[4085];
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
  float4 v6 : TEXCOORD5,
  nointerpolation uint v7 : TEXCOORD6)
{
	// Near distance culling logic
	if (v0.w < MaxDist)
		discard;


  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.x = (uint)v7.x << 4;
  r0.y = max(cb2[r0.x+4].y, cb2[r0.x+4].z);
  r0.y = 1 + -r0.y;
  r0.z = dot(cb2[r0.x+3].xyz, cb2[r0.x+3].xyz);
  r0.z = sqrt(r0.z);
  r0.z = cb3[4].x * r0.z;
  r0.w = cmp(0.999938965 >= r0.y);
  r0.w = r0.w ? 1.000000 : 0;
  r0.zw = r0.zz * r0.ww + v0.xy;
  r0.z = dot(r0.zw, float2(0.0671105608,0.00583714992));
  r0.z = frac(r0.z);
  r0.z = 52.9829178 * r0.z;
  r0.z = frac(r0.z);
  r0.w = cmp(cb2[r0.x+4].x >= 0);
  r0.w = r0.w ? r0.z : -r0.z;
  r0.x = cb2[r0.x+4].x + -r0.w;
  r0.y = r0.y + -r0.z;
  r0.x = min(r0.x, r0.y);
  r0.y = dot(v1.xyz, cb3[13].xyz);
  r0.y = cmp(r0.y >= cb3[7].z);
  r0.y = r0.y ? 1.000000 : 0;
  r0.x = -r0.y * cb3[7].w + r0.x;
  r0.x = cmp(r0.x < 0);
  if (r0.x != 0) discard;
  r0.x = t0.SampleBias(s0_s, v2.xy, cb1[26].x).w;
  r0.y = cb3[5].x + -1;
  r0.z = -cb3[5].x + 1;
  r1.x = cb0[0].z;
  r1.y = cb0[1].z;
  r1.z = cb0[2].z;
  r0.w = dot(r1.xyz, r1.xyz);
  r0.w = max(1.17549435e-38, r0.w);
  r0.w = rsqrt(r0.w);
  r1.xyz = r1.xyz * r0.www;
  r0.w = dot(r1.xyz, v3.xyz);
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
