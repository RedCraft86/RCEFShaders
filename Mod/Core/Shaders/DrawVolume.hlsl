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

cbuffer VolumeData : register(b0)
{
	float3 Color;
	float MaxDist;
}

float4 main(
	float4 clipPos : SV_Position,
	float2 meshUV : TEXCOORD0,
	nointerpolation float viewDist : TEXCOORD1
) : SV_Target
{
	if (MaxDist > 0.0f && viewDist > MaxDist) {
		discard;
	}

	// ----- Editable params -----
	const float innerWidth = 0.75; // Width of the solid edge border in screen-space pixels [0..inf]
	const float outerWidth = 1.25; // Width of the edge transition beyond the solid border [innerWidth..inf]
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

	/**
	 * Triangle Barycentric Coordinates
	 *    Vertex 0 -> (0, 0)
	 *    Vertex 1 -> (1, 0)
	 *    Vertex 2 -> (0, 1)
	 *
	 * This lets us detect the proximity to each edge
	 */
	float3 bary = float3(meshUV, 1.0f - meshUV.x - meshUV.y);

	// Keeps borders consistent in pixel width as distance from camera changes
	float3 ssWidth = fwidth(bary);

	// Find the exterior "edge" of triangles
	float3 interiorMask = smoothstep(ssWidth * innerWidth, ssWidth * outerWidth, bary);
    float interior = min(interiorMask.x, min(interiorMask.y, interiorMask.z));
    float edge = 1.0 - interior; // 1 = edge | 0 = interior

	const float4 faceColor = float4(Color, 0.1f);
	const float4 edgeColor = float4(Color * 0.2f, 0.5f);
	return lerp(faceColor, edgeColor, edge);
}
#endif