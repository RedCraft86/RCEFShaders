// HLSL shaders for RCEFShaders
// Remove fog contribution from Deferred Rendering constant buffer.

cbuffer OriginalCB : register(b0)
{
	uint4 OriginalCB[160];
};

RWBuffer<uint4> PatchedCB : register(u0);

[numthreads(64, 1, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
	uint idx = id.x;
	if (idx >= 160) {
		return;
	}

	uint4 val = OriginalCB[idx];
	if (idx == 73) {
		val.xyz = 0u; // Atmospheric extinction/scattering.
	} else if (idx == 77 || idx == 80) {
		val.y = 0u; // Height-fog densities.
	} else if (idx == 83) {
		val.z = 0u; // Volumetric fog.
	}

	PatchedCB[idx] = val;
}
