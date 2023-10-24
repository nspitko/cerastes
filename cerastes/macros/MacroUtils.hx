package cerastes.macros;

#if !macro

#if hlimgui
import imgui.ImGui;
#end

#end

class MacroUtils
{
	macro public static function swap(a, b) {
		return macro { var v = $a; $a = $b; $b = v; };
	}

	#if hlimgui
	macro public static function imTooltip( contents: haxe.macro.Expr )
	{
		return macro {
			if( ImGui.isItemHovered() )
			{
				ImGui.setTooltip(${contents});
			}
		}
	}
	#end
}