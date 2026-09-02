// CustomShader for RCEFShaders EFMI mod

Texture2D<float4> t20 : register(t20);
Texture2D<float4> t17 : register(t17);
Texture2D<float4> t16 : register(t16);
Texture2D<float4> t15 : register(t15);
Texture2D<float4> t1  : register(t1);

SamplerState s5_s : register(s5);
SamplerState s3_s : register(s3);
SamplerState s0_s : register(s0);

void main(
	float4 v0 : SV_Position0,
	float2 v1 : TEXCOORD0,
	out float4 o0 : SV_Target0)
{
	// Don't draw water pixels hidden behind opaque geometry
	const float waterDepth = t16.SampleLevel(s0_s, v1.xy, 0).x;
	const float sceneDepth = t1.SampleLevel(s0_s, v1.xy, 0).x;
	if (waterDepth < sceneDepth) {
		discard;
	}

	// ---- Editable params ----
	const float3 waterColor = float3(0.10, 0.40, 0.45); // Color to tint the background scene [RGB 0..1]
	const float rippleOverlay = 2.0;                    // Intensity of ripples on the surface [0..inf]
	const float foamOverlay = 2.0;                      // Intensity of pre-baked foam on the surface [0..inf]
	// -------------------------

	// Water normal/flow data, for a bit of ripple distortion ---
	float3 normalTex = t17.SampleLevel(s5_s, v1.xy, 0).xyz; // .xy = octahedral normal, .z = roughness
	float2 oct = normalTex.xy * 2.0 - 1.0;
	float3 n;
	n.z = 1.0 - abs(oct.x) - abs(oct.y);
	n.xy = (n.z < 0.0) ? (1.0 - abs(oct.yx)) * sign(oct.xy) : oct.xy;
	float3 worldNormal = normalize(n);
	float3 waterTint = waterColor * ((normalTex.x + normalTex.y + normalTex.z) / 3) * rippleOverlay;

	// Foam / surface color mask
	float4 surfaceTex = t20.SampleLevel(s0_s, v1.xy, 0);
	waterTint = waterTint + (surfaceTex.xyz * foamOverlay);

	// Cheap "refraction": nudge the sample of whatever's behind the water by the normal
	float2 distortedUV = v1.xy + worldNormal.xz * 0.015;
	float4 behind = t15.SampleLevel(s3_s, distortedUV, 0); // reuse the reflection/scene buffer as backdrop

	// Flat unlit tint, mostly see-through
	o0.xyz = lerp(behind.xyz, waterTint, 0.4);
	o0.w = 1.0; // Does not do anything

	return;
}
