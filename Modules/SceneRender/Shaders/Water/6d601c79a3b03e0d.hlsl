// HLSL shaders for RCEFShaders
// Water

Texture2D<float4> t20 : register(t20);
Texture2D<float4> t17 : register(t17);
Texture2D<float4> t16 : register(t16);
Texture2D<float4> t15 : register(t15);
Texture2D<float4> t1  : register(t1);

SamplerState s3_s : register(s3);
SamplerState s0_s : register(s0);

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	out float4 o0 : SV_Target0
)
{
	// Don't draw water pixels hidden behind opaque geometry
	const float waterDepth = t16.SampleLevel(s0_s, v1.xy, 0).x;
	const float sceneDepth = t1.SampleLevel(s0_s, v1.xy, 0).x;
	if (waterDepth < sceneDepth) {
		discard;
	}

	// ---- Editable params ----
	const float3 waterColor = float3(0.05, 0.20, 0.22); // Color to tint the background scene [RGB 0..1]

	const float rippleOverlay = 2.0;                    // Intensity of ripples on the surface [0..inf]
	const float refractionStrength = 0.025;             // Strength of background distortion caused by ripples [0..1]

	const float waterOpacity = 0.40;                    // Base opacity of the water [0..1]
	const float rippleOpacityStrength = 0.80;           // Additional opacity applied to steep ripples [0..1]
	const float rippleOpacityThreshold = 0.07;          // Minimum normal slope before opacity increases [0..1]
	const float rippleOpacitySoftness = 0.30;           // Smoothness of the opacity transition [0..1]

	const float foamOverlay = 5.0;                      // Intensity of pre-baked foam on the surface [0..inf]
	// -------------------------

	// ---- Decode octahedral normal ----

	float3 normalTex = t17.SampleLevel(s3_s, v1.xy, 0).xyz;
	float2 oct = normalTex.xy * 2.0 - 1.0;

	float3 n;
	n.z = 1.0 - abs(oct.x) - abs(oct.y);
	n.xy = (n.z < 0.0) ? (1.0 - abs(oct.yx)) * sign(oct.xy) : oct.xy;
	float3 worldNormal = normalize(n);

	// ---- Ripple refraction ----

	float2 rippleOffset = worldNormal.xy * refractionStrength * rippleOverlay;
	float2 distortedUV = saturate(v1.xy + rippleOffset);
	float3 behind = t15.SampleLevel(s3_s, distortedUV, 0).xyz;

	// ---- Ripple lighting ----

	float3 lightDir = normalize(float3(0.4, 0.8, 0.5));
	float rippleLight = saturate(dot(worldNormal, lightDir));
	rippleLight = pow(rippleLight, 3.0);

	float3 waterTint = waterColor;
	waterTint += rippleLight * rippleOverlay * 0.15;

	// ---- Existing foam ----

	float4 surfaceTex = t20.SampleLevel(s0_s, v1.xy, 0);
	waterTint += surfaceTex.xyz * foamOverlay;

	// ---- Normal-based opacity ----

	// Measure how tilted the normal is
	float normalSlope = length(worldNormal.xy);

	// Generate opacity variation from normal slope
	float rippleMask = smoothstep(
		rippleOpacityThreshold,
		rippleOpacityThreshold + rippleOpacitySoftness,
		normalSlope
	);

	// Increase opacity on steep ripples
	float finalOpacity = saturate(waterOpacity + rippleMask * rippleOpacityStrength);

	// ---- Final composition ----

	o0.xyz = lerp(behind, waterTint, finalOpacity);
	o0.w = 1.0;
}