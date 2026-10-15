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
	out float3 outRelativePos : TEXCOORD1
)
{
	outMeshUV = meshUV;

	// Blender to Endfield coordinates
	float3 gamePos = float3(meshPos.x, meshPos.z, meshPos.y);
	outRelativePos = gamePos - CameraData[44].xyz;

	float4 clip = CameraData[32] * outRelativePos.x
				+ CameraData[33] * outRelativePos.y
				+ CameraData[34] * outRelativePos.z
				+ CameraData[35];

	clip.y = -clip.y;
	outClipPos = clip;
}
#endif

#ifdef PIXEL_SHADER
Texture2D<float> ViewportSize : register(t1);
Texture2D<float> SceneDepth : register(t2);
Buffer<uint> EdgeMasks : register(t3);

cbuffer AxisXData : register(b0)
{
	float3 ColorX;
	float OpacityX;
}

cbuffer AxisYData : register(b1)
{
	float3 ColorY;
	float OpacityY;
}

cbuffer AxisZData : register(b2)
{
	float3 ColorZ;
	float OpacityZ;
}

float4 main(
	float4 clipPos : SV_Position,
	float2 meshUV : TEXCOORD0,
	float3 relativePos : TEXCOORD1,
	uint primitiveId : SV_PrimitiveID
) : SV_Target
{
	// ----- Editable params -----
	// Approximate screen-space distances measured inward from each triangle edge.
	// Require 0 <= innerWidth < outerWidth; the fade spans outerWidth - innerWidth.
	const float innerWidth = 1.0; // Full edge color up to this distance. [0..inf]
	const float outerWidth = 1.5; // Fade ends at this distance, reaching the face color. [innerWidth..inf]
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

	// Mask bit i describes the edge opposite barycentric corner i. The exporter
	// omits shared coplanar edges so triangulation diagonals never receive a line.
	float3 bary = float3(1.0f - meshUV.x - meshUV.y, meshUV.x, meshUV.y);
	// fwidth keeps the apparent width approximately stable as camera distance changes.
	float3 pixelWidth = fwidth(bary);
	uint mask = EdgeMasks[primitiveId];
	float3 enabledEdges = float3(mask & 1u, (mask >> 1u) & 1u, (mask >> 2u) & 1u);
	float3 edgeStrength = (1.0f - smoothstep(pixelWidth * innerWidth, pixelWidth * outerWidth, bary)) * enabledEdges;
	float edge = max(edgeStrength.x, max(edgeStrength.y, edgeStrength.z));

	// Absolute normal components give opposite-facing surfaces the same axis colors.
	float3 axisNormal = abs(cross(ddx(relativePos), ddy(relativePos)));
	float normalSum = axisNormal.x + axisNormal.y + axisNormal.z;
	float3 axisWeights = axisNormal / (normalSum > 0.0f ? normalSum : 1.0f);
	if (normalSum == 0.0f) {
		axisWeights = float3(0.0f, 1.0f, 0.0f);
	}

	// Add full colors for participating axes; ignore tiny components.
	float3 colorAxes = step(0.01f, axisWeights);
	float3 color = saturate(ColorX * colorAxes.x + ColorY * colorAxes.y + ColorZ * colorAxes.z);
	float opacity = dot(float3(OpacityX, OpacityY, OpacityZ), axisWeights);
	return float4(lerp(color, color * 0.2f, edge), saturate(opacity));
}
#endif
