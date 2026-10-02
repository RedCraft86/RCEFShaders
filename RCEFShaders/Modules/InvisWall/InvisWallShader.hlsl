// Custom Shader for RCEFShaders EFMI mod

#ifdef VERTEX_SHADER
cbuffer CameraCB : register(b0)
{
	float4 cb0[82];
};

cbuffer FrameCB : register(b1)
{
	float4 cb1[20];
};

void main(
	float3 objectPos : POSITION,
	float2 objectUV : TEXCOORD0,
	out float4 outClipPos : SV_Position,
	out float2 outObjectUV : TEXCOORD0,
	out float3 outWorldPos : TEXCOORD1,
	out nointerpolation float outViewDist : TEXCOORD2
)
{
	// Pass mesh UVs to PS for barycentric edge rendering
	outObjectUV = objectUV;

	// Convert Blender coordinates to Endfield world-space coordinates
	float3 gamePos = float3(objectPos.x, objectPos.z, objectPos.y);
	outWorldPos = gamePos;

	// Convert world position to camera-relative position
	float3 relativePos = gamePos - cb0[44].xyz;
	outViewDist = length(relativePos); // Dist from camera for dist culling

	// Transform camera-relative world position into clip space
	float4 clip = cb0[32] * relativePos.x
				+ cb0[33] * relativePos.y
				+ cb0[34] * relativePos.z
				+ cb0[35];

	// Correct vertical projection and output the final clip-space position
	clip.y = -clip.y;
	outClipPos = clip;

	return;
}
#endif

#ifdef PIXEL_SHADER
Texture2D<float> SceneDepth : register(t1);
Texture2D<float> ViewportSize : register(t2);

cbuffer VolumeColor : register(b0)
{
	float4 color;
}

void main(
	float4 clipPos : SV_Position,
	float2 objectUV : TEXCOORD0,
	float3 worldPos : TEXCOORD1,
	nointerpolation float viewDist : TEXCOORD2,
	out float4 outColor : SV_Target
)
{
	// ----- Editable params -----
	const float maxDistance = 400.0;   // Maximum render distance from the camera [0..inf, negative to disable]
	const float innerWidth = 0.75;     // Width of the solid edge border in screen-space pixels [0..inf]
	const float outerWidth = 1.25;     // Width of the edge transition/anti-aliasing beyond the solid border [innerWidth..inf]
	// ---------------------------

	const float4 faceColor = float4(color.rgb, 0.1f);
	const float4 edgeColor = float4(color.rgb * 0.5, 0.5f);

	// Skip rendering tris beyond the render distance
	if (maxDistance > 0.0 && viewDist > maxDistance) {
		discard;
	}

	// Get the size of the depth buffer
	uint depthWidth, depthHeight;
	SceneDepth.GetDimensions(depthWidth, depthHeight);

	// Get the size of the game viewport
	uint resWidth, resHeight;
	ViewportSize.GetDimensions(resWidth, resHeight);

	// Depth buffer is likely at a lower resolution so we create a multiplier
	float2 screenUV = clipPos.xy / float2(resWidth, resHeight);
	screenUV.y = 1.0 - screenUV.y; // It's also upside down

	// Scale into depth texture and clamp within bounds
	int2 depthPixel = int2(screenUV * float2(depthWidth, depthHeight));
	depthPixel = clamp(
		depthPixel, 
		int2(0, 0), 
		int2(depthWidth - 1, depthHeight - 1)
	);

	// Clip parts of the tris that are being occluded by map geometry
	const float sceneDepth = SceneDepth.Load(int3(depthPixel, 0));
	if (clipPos.z < sceneDepth)
	{
		discard;
	}

	// TRIANGLE BARYCENTRIC COORDINATES
	// Exported triangle UVs:
	//   vertex 0 -> (0, 0)
	//   vertex 1 -> (1, 0)
	//   vertex 2 -> (0, 1)
	// This lets us detect proximity to each triangle edge.
	float3 barycentric = float3(
		objectUV.x,	
		objectUV.y,	
		1.0 - objectUV.x - objectUV.y
	);

	// fwidth() keeps borders consistent in pixel width as distance from the camera changes.
	float3 ssWidth = fwidth(barycentric);

	// Find the exterior "edge" of the triangles
	float3 interiorMask = smoothstep(ssWidth * innerWidth, ssWidth * outerWidth, barycentric);
	float interior = min(interiorMask.x, min(interiorMask.y, interiorMask.z));
	float edge = 1.0 - interior; // 1 = edge / 0 = interior

	outColor = lerp(faceColor, edgeColor, edge);

	return;
}
#endif