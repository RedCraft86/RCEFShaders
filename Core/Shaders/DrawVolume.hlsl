// HLSL shaders for RCEFShaders

#ifdef VERTEX_SHADER
cbuffer CameraBuffer : register(b0)
{
	float4 CameraData[45];
};

void main(
	float3 meshPos : POSITION,
	float2 meshUV : TEXCOORD0,
	out float4 outClipPos : SV_Position,
	out float2 outMeshUV : TEXCOORD0,
	out nointerpolation float outViewDist : TEXCOORD1
)
{
	outMeshUV = meshUV;

	// Blender to Endfield coordinates
	float3 gamePos = float3(meshPos.x, meshPos.z, meshPos.y);
	float3 relativePos = gamePos - CameraData[44].xyz;

	outViewDist = length(relativePos);

	float4 clip = CameraData[32] * relativePos.x
				+ CameraData[33] * relativePos.y
				+ CameraData[34] * relativePos.z
				+ CameraData[35];

	clip.y = -clip.y;
	outClipPos = clip;
}
#endif

#ifdef PIXEL_SHADER
Texture2D<float> ViewportSize : register(t1);
Texture2D<float> SceneDepth : register(t2);
Buffer<uint> EdgeMasks : register(t3);

cbuffer VolumeData : register(b0)
{
	float3 Color;
	float MaxDist;
}

float4 main(
	float4 clipPos : SV_Position,
	float2 meshUV : TEXCOORD0,
	nointerpolation float viewDist : TEXCOORD1,
	uint primitiveId : SV_PrimitiveID
) : SV_Target
{
	if (MaxDist > 0.0f && viewDist > MaxDist) {
		discard;
	}

	// ----- Editable params -----
	// Approximate screen-space distances measured inward from each triangle edge.
	// Require 0 <= innerWidth < outerWidth; the fade spans outerWidth - innerWidth.
	const float innerWidth = 0.75; // Full edge color up to this distance. [0..inf]
	const float outerWidth = 1.25; // Fade ends at this distance, reaching the face color. [innerWidth..inf]
	// ---------------------------

	uint resWidth, resHeight;
	ViewportSize.GetDimensions(resWidth, resHeight);

	uint depthWidth, depthHeight;
	SceneDepth.GetDimensions(depthWidth, depthHeight);

	// Multiplier as the depth buffer may exist at a different resolution from viewport
	float2 screenUV = clipPos.xy / float2(resWidth, resHeight);
	screenUV.y = 1.0f - screenUV.y; // Flip it since it's also upside down

	int2 depthUV = int2(screenUV * float2(depthWidth, depthHeight));
	depthUV = clamp(depthUV, int2(0, 0), int2(depthWidth - 1, depthHeight - 1));
	const float pixelDepth = SceneDepth.Load(int3(depthUV, 0));
	if (clipPos.z < pixelDepth) {
		// Discard pixels that are occluded by map geometry
		discard;
	}

	// Mask bit i enables the edge opposite triangle corner i. Compute derivatives
	// before discard branches, and suppress shared coplanar edges using exporter masks.
	float3 bary = float3(1.0f - meshUV.x - meshUV.y, meshUV.x, meshUV.y);
	float3 pixelWidth = fwidth(bary);
	uint mask = EdgeMasks[primitiveId];
	float3 enabledEdges = float3(mask & 1u, (mask >> 1u) & 1u, (mask >> 2u) & 1u);
	float3 edgeStrength = (1.0f - smoothstep(pixelWidth * innerWidth, pixelWidth * outerWidth, bary)) * enabledEdges;
	float edge = max(edgeStrength.x, max(edgeStrength.y, edgeStrength.z));

	const float4 faceColor = float4(Color, 0.1f);
	const float4 edgeColor = float4(Color * 0.2f, 0.5f);
	return lerp(faceColor, edgeColor, edge);
}
#endif
