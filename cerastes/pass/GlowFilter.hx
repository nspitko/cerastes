package cerastes.pass;

import h2d.filter.Glow;
import h2d.filter.Filter;

#if hlimgui
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import cerastes.macros.MacroUtils.imTooltip;
#end


@:structInit class GlowFilterDef extends cerastes.fmt.CUIResource.CUIFilterDef
{
	@cd_type("Int") public var color: Int = 0;
	@cd_type("Float") public var alpha: Float = 1;
	@cd_type("Bool") public var smoothColor: Bool = false;
}

@:keep
class GlowFilter extends Glow implements SelectableFilter
{
	#if hlimgui
	@:keep public static function getEditorName() { return "\uf07c Glow"; }
	@:keep public static function getDef() : GlowFilterDef { return {}; }
	@:keep public static function getInspector( def: GlowFilterDef ) {

		var nc = IG.inputColorInt( def.color, "Color" );
		if( nc != null )
			def.color = nc;

		ImGui.inputDouble("alpha",def.alpha,0.01,0.1);
		
		ImGui.checkbox("smooth color",def.smoothColor);
		imTooltip("Produce gradient shadow when enabled, otherwise creates hard shadow without smoothing.");
	}
	#end

	public function new( ?def: GlowFilterDef  ) {
		if( def != null )
			super( def.color, def.alpha, def.smoothColor );
		else
			super();
	}


}
