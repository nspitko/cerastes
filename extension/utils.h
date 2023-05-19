#pragma once

#define HL_NAME(n) cerastes_##n

#include <string>
#include <hl.h>
#include <vector>
#include <tchar.h>

#define convertString(st) st != nullptr ? unicodeToUTF8(st).c_str() : NULL
#define convertStringNullAsEmpty(st) st != nullptr ? unicodeToUTF8(st).c_str() : ""
#define convertPtr(ptr,default_value) ptr != nullptr ? *ptr : default_value
#define convertArray(arr,type) arr != nullptr ? hl_aptr(arr,type) : nullptr
#define arraySize(a) \
  ((sizeof(a) / sizeof(*(a))) / \
  static_cast<size_t>(!(sizeof(a) % sizeof(*(a)))))

#ifdef __APPLE__
#define throw_error(err) hl_throw(hl_alloc_strbytes((const uchar*)(USTR(err))))
#else
#define throw_error(err) hl_error(err)
#endif

// Usage:
// DEFINE_PRIM_PROP(_I32,prop_name,_REF(_I32))
// Equates to:
// DEFINE_PRIM(_I32,get_prop_name,_NO_ARG)
// DEFINE_PRIM(_VOID,set_prop_name,_REF(_I32))
#define DEFINE_PRIM_PROP(t,name,args) DEFINE_PRIM(t,get_##name,_NO_ARG)\
	DEFINE_PRIM(_VOID,set_##name,args)

std::string unicodeToUTF8(vstring* hl_string);
vbyte* getVByteFromCStr(const char* str);
vbyte* getVByteFromTChar(const TCHAR* str);