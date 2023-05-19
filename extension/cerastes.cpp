#include "utils.h"
#include "ShlObj.h"

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

DEFINE_PRIM(_BYTES, get_folder_path, _I32 );