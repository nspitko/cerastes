package cerastes;

@:enum abstract CSIDL(Int) from Int to Int {

	var CSIDL_DESKTOP                   = 0x0000;        // <desktop>
	var CSIDL_INTERNET                  = 0x0001;        // Internet Explorer (icon on desktop)
	var CSIDL_PROGRAMS                  = 0x0002;        // Start Menu\Programs
	var CSIDL_CONTROLS                  = 0x0003;        // My Computer\Control Panel
	var CSIDL_PRINTERS                  = 0x0004;        // My Computer\Printers
	var CSIDL_PERSONAL                  = 0x0005;        // My Documents
	var CSIDL_FAVORITES                 = 0x0006;        // <user name>\Favorites
	var CSIDL_STARTUP                   = 0x0007;        // Start Menu\Programs\Startup
	var CSIDL_RECENT                    = 0x0008;        // <user name>\Recent
	var CSIDL_SENDTO                    = 0x0009;        // <user name>\SendTo
	var CSIDL_BITBUCKET                 = 0x000a;        // <desktop>\Recycle Bin
	var CSIDL_STARTMENU                 = 0x000b;        // <user name>\Start Menu
	var CSIDL_MYDOCUMENTS               = CSIDL_PERSONAL; //  Personal was just a silly name for My Documents
	var CSIDL_MYMUSIC                   = 0x000d;        // "My Music" folder
	var CSIDL_MYVIDEO                   = 0x000e;        // "My Videos" folder
	var CSIDL_DESKTOPDIRECTORY          = 0x0010;        // <user name>\Desktop
	var CSIDL_DRIVES                    = 0x0011;        // My Computer
	var CSIDL_NETWORK                   = 0x0012;        // Network Neighborhood (My Network Places)
	var CSIDL_NETHOOD                   = 0x0013;        // <user name>\nethood
	var CSIDL_FONTS                     = 0x0014;        // windows\fonts
	var CSIDL_TEMPLATES                 = 0x0015;
	var CSIDL_COMMON_STARTMENU          = 0x0016;        // All Users\Start Menu
	var CSIDL_COMMON_PROGRAMS           = 0x0017;        // All Users\Start Menu\Programs
	var CSIDL_COMMON_STARTUP            = 0x0018;        // All Users\Startup
	var CSIDL_COMMON_DESKTOPDIRECTORY   = 0x0019;        // All Users\Desktop
	var CSIDL_APPDATA                   = 0x001a;        // <user name>\Application Data
	var CSIDL_PRINTHOOD                 = 0x001b;        // <user name>\PrintHood

	var CSIDL_LOCAL_APPDATA             = 0x001c;        // <user name>\Local Settings\Applicaiton Data (non roaming)

	var CSIDL_ALTSTARTUP                = 0x001d;        // non localized startup
	var CSIDL_COMMON_ALTSTARTUP         = 0x001e;        // non localized common startup
	var CSIDL_COMMON_FAVORITES          = 0x001f;

	var CSIDL_INTERNET_CACHE            = 0x0020;
	var CSIDL_COOKIES                   = 0x0021;
	var CSIDL_HISTORY                   = 0x0022;
	var CSIDL_COMMON_APPDATA            = 0x0023;        // All Users\Application Data
	var CSIDL_WINDOWS                   = 0x0024;        // GetWindowsDirectory()
	var CSIDL_SYSTEM                    = 0x0025;        // GetSystemDirectory()
	var CSIDL_PROGRAM_FILES             = 0x0026;        // C:\Program Files
	var CSIDL_MYPICTURES                = 0x0027;        // C:\Program Files\My Pictures

	var CSIDL_PROFILE                   = 0x0028;        // USERPROFILE
	var CSIDL_SYSTEMX86                 = 0x0029;        // x86 system directory on RISC
	var CSIDL_PROGRAM_FILESX86          = 0x002a;        // x86 C:\Program Files on RISC

	var CSIDL_PROGRAM_FILES_COMMON      = 0x002b;        // C:\Program Files\Common

	var CSIDL_PROGRAM_FILES_COMMONX86   = 0x002c;        // x86 Program Files\Common on RISC
	var CSIDL_COMMON_TEMPLATES          = 0x002d;        // All Users\Templates

	var CSIDL_COMMON_DOCUMENTS          = 0x002e;        // All Users\Documents
	var CSIDL_COMMON_ADMINTOOLS         = 0x002f;        // All Users\Start Menu\Programs\Administrative Tools
	var CSIDL_ADMINTOOLS                = 0x0030;        // <user name>\Start Menu\Programs\Administrative Tools

	var CSIDL_CONNECTIONS               = 0x0031;        // Network and Dial-up Connections
	var CSIDL_COMMON_MUSIC              = 0x0035;        // All Users\My Music
	var CSIDL_COMMON_PICTURES           = 0x0036;        // All Users\My Pictures
	var CSIDL_COMMON_VIDEO              = 0x0037;        // All Users\My Video
	var CSIDL_RESOURCES                 = 0x0038;        // Resource Direcotry

	var CSIDL_RESOURCES_LOCALIZED       = 0x0039;        // Localized Resource Direcotry

	var CSIDL_COMMON_OEM_LINKS          = 0x003a;        // Links to All Users OEM specific apps
	var CSIDL_CDBURN_AREA               = 0x003b;        // USERPROFILE\Local Settings\Application Data\Microsoft\CD Burning
	// unused                               = 0x003c
	var CSIDL_COMPUTERSNEARME           = 0x003d;        // Computers Near Me (computered from Workgroup membership)

	var CSIDL_FLAG_CREATE               = 0x8000;        // combine with CSIDL_ value to force folder creation in SHGetFolderPath()

	var CSIDL_FLAG_DONT_VERIFY          = 0x4000;        // combine with CSIDL_ value to return an unverified folder path
	var CSIDL_FLAG_DONT_UNEXPAND        = 0x2000;        // combine with CSIDL_ value to avoid unexpanding environment variables

	var CSIDL_FLAG_NO_ALIAS             = 0x1000;        // combine with CSIDL_ value to insure non-alias versions of the pidl
	var CSIDL_FLAG_PER_USER_INIT        = 0x0800;        // combine with CSIDL_ value to indicate per-user init (eg. upgrade)

	var CSIDL_FLAG_MASK                 = 0xFF00;        // mask for all possible flag values
}

@:hlNative("cerastes")
class Native
{
	static function get_folder_path( cisdl: Int ) : hl.Bytes {return null;}
	public static inline function getFolderPath( cisdl: CSIDL ) : String {
		return @:privateAccess String.fromUTF8( get_folder_path( cisdl ) );
	}
}