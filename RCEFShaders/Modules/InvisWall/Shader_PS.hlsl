// CustomShader for RCEFShaders EFMI mod

Texture2D<float> SceneDepth : register(t1);
Texture1D<float4> IniParams : register(t120);

void main(
	float4 clipPos : SV_Position,
	float2 objectUV : TEXCOORD0,
	float3 worldPos : TEXCOORD1,
	nointerpolation float viewDist : TEXCOORD2,
	out float4 outColor : SV_Target
)
{
	// ----- Editable params -----
	const float4 faceColor = float4(0.0, 1.0, 1.0, 0.1);  // Color and Opacity for wall faces [RGBA 0..1]
	const float4 edgeColor = float4(0.0, 0.1, 0.3, 0.5);  // Color and Opacity for wall edges [RGBA 0..1]

	const float maxDistance = 800.0;   // Maximum render distance from the camera [0..inf, negative to disable]
	const float innerWidth = 0.75;     // Width of the solid edge border in screen-space pixels [0..inf]
	const float outerWidth = 1.25;     // Width of the edge transition/anti-aliasing beyond the solid border [innerWidth..inf]
	// ---------------------------

	// Skip rendering tris beyond the render distance
	if (maxDistance > 0.0 && viewDist > maxDistance) {
		discard;
	}

	uint depthWidth, depthHeight;
	SceneDepth.GetDimensions(depthWidth, depthHeight);

	// Convert screen pixel to normalized coordinates
	float2 screenUV = clipPos.xy / float2(IniParams[180].x, IniParams[180].y);
	screenUV.y = 1.0 - screenUV.y; // Depth texture is upside down

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