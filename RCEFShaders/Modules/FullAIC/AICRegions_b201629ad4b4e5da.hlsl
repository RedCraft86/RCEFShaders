// CustomShader for RCEFShaders EFMI mod

cbuffer cb0 : register(b0)
{
	float4 cb0[28];
}

cbuffer cb1 : register(b1)
{
	float4 cb1[105];
}

void main(
	float4 v0 : SV_Position0,
	float4 v1 : TEXCOORD0,
	float4 v2 : TEXCOORD1,
	float4 v3 : TEXCOORD2,
	float4 v4 : TEXCOORD3,
	float4 v5 : TEXCOORD4,
	float4 v6 : TEXCOORD5,
	nointerpolation uint v7 : TEXCOORD6,
	out float4 o0 : SV_Target0,
	out float4 o1 : SV_Target1)
{
	// ----- Editable params -----
	const float Opacity = 0.1;                   // Face opacity [0..1]
	const float3 ColorA = float3(0.1, 0.1, 0.5); // X-dominant face color [RGB 0..1]
	const float3 ColorB = float3(0.5, 0.1, 0.1); // Z-dominant face color [RGB 0..1]
	// ---------------------------

	float2 screenUV = v0.xy * cb1[0].zw;
	float2 ndc = screenUV * float2(2.0, -2.0) + float2(-1.0, 1.0);

	float4 clipPos;
	clipPos.xy = ndc;
	clipPos.z = v0.z;
	clipPos.w = 1.0;

	float4 worldPos = cb0[24] * clipPos.x 
				+ cb0[25] * clipPos.y 
				+ cb0[26] * clipPos.z 
				+ cb0[27];

	worldPos.xyz /= worldPos.w;

	float3 dpdx = ddx(worldPos.xyz);
	float3 dpdy = ddy(worldPos.xyz);
	float3 faceNormal = normalize(cross(dpdx, dpdy));
	float faceFactor = step(abs(faceNormal.z), abs(faceNormal.x));

	float3 finalColor = lerp(ColorA, ColorB, faceFactor);

	o0 = float4(finalColor, Opacity);
	o1 = float4(0.0, 0.0, 1.0, 0.0); // Don't touch, it's a motion vector output

	return;
}