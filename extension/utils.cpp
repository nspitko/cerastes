#include "utils.h"

std::string unicodeToUTF8(vstring* hl_string)
{
	std::string result;

	for (int i = 0; i < hl_string->length; i++)
	{
		auto code = ((unsigned short*)hl_string->bytes)[i];
		if (code <= 0x7F)
		{
			result += char(code);
		}
		else if (code <= 0x7FF)
		{
			result += char(0xC0 | (code >> 6));            /* 110xxxxx */
			result += char(0x80 | (code & 0x3F));          /* 10xxxxxx */
		}
		else
		{
			result += char(0xE0 | (code >> 12));           /* 1110xxxx */
			result += char(0x80 | ((code >> 6) & 0x3F));   /* 10xxxxxx */
			result += char(0x80 | (code & 0x3F));          /* 10xxxxxx */
		}
	}

	return result;
}

vbyte* getVByteFromCStr(const char* str)
{
	int size = int(strlen(str) + 1);
	vbyte* result = hl_alloc_bytes(size);
	memcpy(result, str, size);
	return result;
}

vbyte* getVByteFromTChar(const TCHAR* str)
{
	int size = (int)(_tcslen( str ) * sizeof(str)) + 1;
	vbyte* result = hl_alloc_bytes(size);
	memcpy(result, str, size);
	return result;
}