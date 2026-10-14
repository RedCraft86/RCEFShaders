// HLSL shaders for RCEFShaders
// AIC Region

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
	const float3 lineColor = float3(0.0, 1.0, 1.0); // Linear RGB, before game color grading.
	const float3 fillColor = float3(0.0, 1.0, 1.0); // Linear RGB, before game color grading.
	const float lineOpacity = 0.5;       // [0..1]
	const float backgroundOpacity = 0.1; // [0..1]; use 0 for lines only.
	const float lineWidth = 0.05;        // World units, perpendicular to the lines; <= 0 hides lines.
	const float lineGap = 0.95;          // Clear gap in world units; <= 0 gives solid lines.
	const float lineAngleDegrees = 45.0; // 0 = lines along the face's horizontal axis.
	const float patternOffset = 0.0;     // World units, along the stripe normal.
	const float panSpeed = 0.25;         // Horizontal world units per game-clock unit; 0 stops, negative reverses.
	// ---------------------------

	// Reconstruct world position without scene-depth sampling or distance fades.
	float2 screenUV = v0.xy * cb1[0].zw;
	float2 ndc = screenUV * float2(2.0, -2.0) + float2(-1.0, 1.0);
	float4 worldPosition = cb0[24] * ndc.x
						 + cb0[25] * ndc.y
						 + cb0[26] * v0.z
						 + cb0[27];
	float safeW = worldPosition.w >= 0.0 ? max(worldPosition.w, 1e-8) : min(worldPosition.w, -1e-8);
	float3 worldPos = worldPosition.xyz / safeW;

	// Y is up: walls use (Z,Y) or (X,Y), floors use (X,Z).
	// Absolute normal keeps the projection independent of winding and camera side.
	float3 normal = abs(cross(ddx(worldPos), ddy(worldPos)));
	float2 facePosition;
	if (normal.x >= normal.y && normal.x >= normal.z) {
		facePosition = worldPos.zy;
	} else if (normal.y >= normal.z) {
		facePosition = worldPos.xz;
	} else {
		facePosition = worldPos.xy;
	}

	// TEXCOORD2.z carries the original UV animation clock from VS cb2[103].w.
	// Translate the horizontal axis before rotating into stripe coordinates.
	// At 0 degrees this motion runs along the lines and is visually unchanged.
	facePosition.x -= v3.z * panSpeed;
	float width = max(lineWidth, 0.0);
	float gap = max(lineGap, 0.0);
	float period = max(width + gap, 1e-6);
	float angle = radians(lineAngleDegrees);
	float2 stripeNormal = float2(-sin(angle), cos(angle));
	float coordinate = dot(facePosition, stripeNormal) - patternOffset;
	float phase = (coordinate + width * 0.5) / period;
	float footprint = max(fwidth(phase), 1e-5);
	float dutyCycle = width / period;

	// Integrate periodic stripe coverage across the pixel footprint. Distant
	// lines average to their coverage instead of disappearing or aliasing.
	float center = frac(phase);
	float2 bounds = center + footprint * float2(-0.5, 0.5);
	float2 integrals = floor(bounds) * dutyCycle + min(frac(bounds), dutyCycle);
	float coverage = saturate((integrals.y - integrals.x) / footprint);
	if (width <= 0.0) {
		coverage = 0.0;
	} else if (gap <= 0.0) {
		coverage = 1.0;
	}

	float3 color = clamp(lerp(fillColor, lineColor, coverage), 0.0, 1000.0);
	float opacity = saturate(lerp(backgroundOpacity, lineOpacity, coverage));

	// Preserve the game's per-instance opacity and screen-door visibility.
	float2 visibility = cb2[(v7 << 4u) + 4u].xy;
	float noise = frac(52.9829178 * frac(dot(v0.xy, float2(0.0671105608, 0.00583714992))));
	float signedNoise = visibility.x >= 0.0 ? noise : -noise;
	float instanceCoverage = visibility.x - signedNoise > 0.0 ? 1.0 : 1.0 - cb3[0].x;
	opacity *= (1.0 - visibility.y) * instanceCoverage;

	// Preserve the original render-target encoding for the material's blend mode.
	float blendMode = cb3[0].y;
	float inverseBlendMode = 1.0 - blendMode;
	float3 encodedColor = color * opacity;
	if (blendMode == 2.0) {
		encodedColor += 1.0 - opacity;
	}

	const float3 luminanceWeights = float3(0.212672904, 0.715152204, 0.0721750036);
	float luminance = dot(encodedColor, luminanceWeights);
	float3 gradedColor = (luminance + cb1[104].w * (encodedColor - luminance)) * cb1[104].xyz;
	o1.rgb = lerp(encodedColor, gradedColor, cb3[2].w);
	o1.a = opacity * max(0.0, inverseBlendMode);

	// Preserve the second target's encoded motion and material mask.
	float2 currentNDC = v5.xy / max(1e-8, v5.z);
	float2 previousNDC = v6.xy / max(1e-8, v6.z);
	float2 motion = (currentNDC - previousNDC) * float2(0.5, -0.5);
	float2 encodedMotion = sign(motion) * sqrt(sqrt(abs(motion))) * 0.5 + 0.5;
	bool writeMotion = saturate(1.0 + cb3[0].w - cb3[0].x) > 0.5;
	o2.xy = writeMotion ? min(float2(1.0, 1.0), encodedMotion) : float2(0.0, 0.0);
	o2.z = 1.0;

	float maskCoverage = max(dot(color, luminanceWeights) * opacity, opacity * inverseBlendMode);
	float materialMask = saturate(10.0 * maskCoverage) > 0.5 ? 1.0 : 0.0;
	o2.w = cb3[0].z * cb3[0].x * materialMask;
}