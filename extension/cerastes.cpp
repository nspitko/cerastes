#include "utils.h"
#include "ShlObj.h"
#include "WinUser.h"

#define THWND _ABSTRACT(dx_window)

HL_PRIM vbyte* HL_NAME(get_folder_path)( int cisdl )
{

	TCHAR szPath[MAX_PATH];

	if(SUCCEEDED(SHGetFolderPath(NULL,
                             cisdl,
                             NULL,
                             0,
                             szPath)))
	{
		return getVByteFromTChar( szPath );
	}

	return nullptr;
}

HL_PRIM int HL_NAME(get_dpi_for_window)( HWND hWnd )
{
	return GetDpiForWindow( hWnd );
}

DEFINE_PRIM(_BYTES, get_folder_path, _I32 );
DEFINE_PRIM(_I32, get_dpi_for_window, THWND );