// CustomShader for RCEFShaders EFMI mod

cbuffer TerrainCB0 : register(b0)
{
	float4 cb0[82];
};

RWBuffer<uint> OutputText : register(u0);

void WriteChar(inout uint index, uint character)
{
	if (index < 127)
	{
		OutputText[index] = character;
		index++;
	}
}

void WriteUInt(inout uint index, uint value)
{
	uint digits[10];
	uint count = 0;

	if (value == 0)
	{
		WriteChar(index, 48); // '0'
		return;
	}

	while (value > 0 && count < 10)
	{
		digits[count] = value % 10;
		value /= 10;
		count++;
	}

	while (count > 0)
	{
		count--;

		WriteChar(
			index,
			48 + digits[count]
		);
	}
}

void WriteFloat3(inout uint index, float value)
{
	if (value < 0.0)
	{
		WriteChar(index, 45); // '-'
		value = -value;
	}

	uint integerPart = (uint)floor(value);
	float fractionalValue = value - floor(value);
	uint fractionalPart =(uint)round(fractionalValue * 1000.0);

	// Handle rounding such as: 12.9997 -> 13.000
	if (fractionalPart >= 1000)
	{
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
	WriteChar(index, 32); // space
}

[numthreads(1, 1, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
	[unroll]
	for (uint i = 0; i < 128; i++)
	{
		OutputText[i] = 0;
	}

	float3 position = cb0[44].xyz;

	// Construct: "X: 123.456   Y: 123.456   Z: 123.456"
	uint index = 0;

	// X
	WriteLabel(
		index,
		88 // X
	);

	WriteFloat3(
		index,
		position.x
	);

	// Spaces
	WriteChar(index, 32);
	WriteChar(index, 32);
	WriteChar(index, 32);

	// Y
	WriteLabel(
		index,
		89
	);

	WriteFloat3(
		index,
		position.y
	);

	// Spaces
	WriteChar(index, 32);
	WriteChar(index, 32);
	WriteChar(index, 32);

	// Z
	WriteLabel(
		index,
		90
	);

	WriteFloat3(
		index,
		position.z
	);


	// Null terminator
	if (index < 128)
	{
		OutputText[index] = 0;
	}
}