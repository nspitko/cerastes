package cerastes.macros;

class MacroUtils
{
	macro public static function swap(a, b) {
		return macro { var v = $a; $a = $b; $b = v; };
	}
}