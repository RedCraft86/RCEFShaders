// CustomShader for RCEFShaders EFMI mod

cbuffer cb2 : register(b2)
{
	float4 cb2[4095];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[105];
}

cbuffer cb0 : register(b0)
{
	float4 cb0[45];
}

void main(
	float4 v0 : SV_Position0,
	float4 v1 : TEXCOORD0,
	float4 v2 : TEXCOORD1,
	float4 v3 : TEXCOORD2,
	float4 v4 : TEXCOORD3,
	float4 v5 : TEXCOORD4,
	float4 v6 : TEXCOORD5,
	float4 v7 : TEXCOORD6,
	nointerpolation uint v8 : TEXCOORD7,
	out float4 o0 : SV_Target0,
	out float4 o1 : SV_Target1)
{
	// ----- Editable params -----
	const float Opacity = 1.0;                    // Slice opacity [0..1]
	const float3 ColorA = float3(0.5, 0.0, 0.5);  // Invalid tiles color [RGB 0..1]
	const float3 ColorB = float3(0.5, 0.5, 0.0);  // Valid tiles color [RGB 0..1]
	const float sideShade = 0.5;                  // Brightness multiplier for the side shading [0..1]

	const float sliceTop = -0.1;                  // Height of the top face of the slice [-0.5 (bottom) .. 0.5 (top)]
	const float sliceHalfSize = 0.5;              // Half size of the slices [0..0.5]
	const float sliceDepth = 1.0;                 // How far the slize extends downward from sliceTop [0..inf]
	// ---------------------------

	// World position from this pixel's own screen pos + depth
	float2 screenUV = cb1[0].zw * v0.xy;
	float3 ndcPos = float3(screenUV * float2(2, 2) + float2(-1, -1), v0.z);

	float4 clipPos = cb0[25] * -ndcPos.yyyy;
	clipPos = cb0[24] * ndcPos.xxxx + clipPos;
	clipPos = cb0[26] * ndcPos.zzzz + clipPos;
	clipPos = cb0[27] + clipPos;
	float3 worldPos = clipPos.xyz / clipPos.www;

	// Box-local space
	float3 origin = float3(v1.w, v2.w, v3.w);
	float3 localPos = float3(
		dot(v1.xyz, worldPos - origin),
		dot(v2.xyz, worldPos - origin),
		dot(v3.xyz, worldPos - origin)
	);

	// Per-instance color flag (bit 4 of packed instance data)
	uint instanceOffset = v8.x << 4;
	float3 origColor = cb2[instanceOffset + 13].xyz;
	bool isRed = origColor.x > 0.5 && origColor.y < 0.5;
	float3 tileColor = isRed ? ColorA : ColorB;

	// Ray from camera through this pixel, extended to the slice height plane
	float3 camPos = cb0[44].xyz;
	float3 camLocal = float3(
		dot(v1.xyz, camPos - origin),
		dot(v2.xyz, camPos - origin),
		dot(v3.xyz, camPos - origin)
	);
	float3 rayDir = normalize(localPos - camLocal);

	// Ray-AABB intersection against the slab volume
	float3 slabMin = float3(-sliceHalfSize, sliceTop - sliceDepth, -sliceHalfSize);
	float3 slabMax = float3(sliceHalfSize, sliceTop, sliceHalfSize);

	float3 invDir = 1.0 / rayDir;
	float3 tMin3 = (slabMin - camLocal) * invDir;
	float3 tMax3 = (slabMax - camLocal) * invDir;
	float3 tNear3 = min(tMin3, tMax3);
	float3 tFar3 = max(tMin3, tMax3);
	float tNear = max(max(tNear3.x, tNear3.y), tNear3.z);
	float tFar = min(min(tFar3.x, tFar3.y), tFar3.z);

	bool hitSlab = (tNear <= tFar) && (tFar > 0);
	float sliceAlpha = hitSlab ? 1.0 : 0.0;

	// Which axis produced the entry point tells us which face was hit
	bool hitTop = (tNear == tNear3.y);
	float shade = hitTop ? 1.0 : sideShade;

	o0 = float4(tileColor * shade, Opacity) * sliceAlpha;
	o1 = float4(0.0, 0.0, 1.0, 0.0); // Don't touch, it's a motion vector output

	return;
}
