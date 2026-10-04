// HLSL shaders for RCEFShaders
// Writes character coordinates from the terrain lighting-volume anchor.

cbuffer PlayerCB : register(b0)
{
	float4 PlayerData[1];
};

RWBuffer<uint> OutputText : register(u0);

// Must match ResourceCoordText's array size in Coordinates.ini.
static const uint TEXT_CAPACITY = 128;

void WriteChar(inout uint index, uint character)
{
	if (index < TEXT_CAPACITY - 1) {
		OutputText[index] = character;
		index++;
	}
}

void WriteUInt(inout uint index, uint value)
{
	uint digits[10];
	uint count = 0;

	if (value == 0) {
		WriteChar(index, 48); // '0'
		return;
	}

	while (value > 0 && count < 10) {
		digits[count] = value % 10;
		value /= 10;
		count++;
	}

	while (count > 0) {
		count--;

		WriteChar(
			index,
			48 + digits[count]
		);
	}
}

void WriteFloat3(inout uint index, float value)
{
	if (value < 0.0) {
		WriteChar(index, 45); // '-'
		value = -value;
	}

	uint integerPart = (uint)floor(value);
	float fractionalValue = value - floor(value);
	uint fractionalPart =(uint)round(fractionalValue * 1000.0);

	// Handle rounding such as: 12.9997 -> 13.000
	if (fractionalPart >= 1000) {
		integerPart++;
		fractionalPart = 0;
	}

	WriteUInt(
		index,
		integerPart
	);

	WriteChar(
		index,
		46 // '.'
	);


	// Hundreds digit
	WriteChar(
		index,
		48 + ((fractionalPart / 100) % 10)
	);

	// Tens digit
	WriteChar(
		index,
		48 + ((fractionalPart / 10) % 10)
	);

	// Ones digit
	WriteChar(
		index,
		48 + (fractionalPart % 10)
	);
}

void WriteLabel(inout uint index, uint letter)
{
	WriteChar(index, letter);
	WriteChar(index, 58); // ':'
}

void WritePosition(inout uint index, float3 position)
{
	WriteLabel(index, 88); // X
	WriteFloat3(index, position.x);
	WriteChar(index, 32);
	WriteLabel(index, 89); // Y
	WriteFloat3(index, position.y);
	WriteChar(index, 32);
	WriteLabel(index, 90); // Z
	WriteFloat3(index, position.z);
}

[numthreads(1, 1, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
	[unroll]
	for (uint i = 0; i < TEXT_CAPACITY; i++) {
		OutputText[i] = 0;
	}

	uint index = 0;

	// ViewConstants extracts terrain FrameCB[132]; preserve XYZ order.
	WritePosition(index, PlayerData[0].xyz);

	// WriteChar always reserves the last slot for the null terminator.
	OutputText[index] = 0;
}