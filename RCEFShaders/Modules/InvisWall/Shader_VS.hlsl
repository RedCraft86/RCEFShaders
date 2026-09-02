// CustomShader for RCEFShaders EFMI mod

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