package cerastes.pass;

import h2d.filter.DropShadow;
import h2d.filter.Filter;

#if hlimgui
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import cerastes.macros.MacroUtils.imTooltip;
#end


@:structInit class DropShadowFilterDef extends cerastes.fmt.CUIResource.CUIFilterDef
{
	@cd_type("Float") public var distance: Float = 4;
	@cd_type("Float") public var angle: Float = 0.785;
	@cd_type("Int") public var color: Int = 0;
	@cd_type("Float") public var alpha: Float = 1;
	@cd_type("Float") public var radius: Float = 1;
	@cd_type("Float") public var gain: Float = 1;
	@cd_type("Float") public var quality: Float = 1;
	@cd_type("Bool") public var smoothColor: Bool = false;
}

@:keep
class DropShadowFilter extends DropShadow implements SelectableFilter
{
	#if hlimgui
	@:keep public static function getEditorName() { return "\uf07c Drop Shadow"; }
	@:keep public static function getDef() : DropShadowFilterDef { return {}; }
	@:keep public static function getInspector( def: DropShadowFilterDef ) {
		ImGui.inputDouble("distance",def.distance,0.5,1);
		imTooltip("The offset of the shadow in the `angle` direction.");
		var ang: Single = def.angle;
		if( ImGui.sliderAngle("angle",ang) ) def.angle = ang;
		imTooltip("Shadow offset direction angle.");

		var nc = IG.inputColorInt( def.color, "Color" );
		if( nc != null )
			def.color = nc;

		ImGui.inputDouble("alpha",def.alpha,0.01,0.1);
		ImGui.inputDouble("radius",def.radius,0.1,1);
		imTooltip("The shadow glow distance in pixels.");
		ImGui.inputDouble("gain",def.gain,0.1,0.25);
		imTooltip("The shadow color intensity.");
		ImGui.inputDouble("quality",def.quality,0.5,1);
		imTooltip("The sample count on each pixel as a tradeoff of speed/quality.");
		ImGui.checkbox("smooth color",def.smoothColor);
		imTooltip("Produce gradient shadow when enabled, otherwise creates hard shadow without smoothing.");

	}
	#end

	public function new( ?def: DropShadowFilterDef  ) {
		if( def != null )
			super( def.distance, def.angle, def.color, def.alpha, def.radius, def.gain, def.quality, def.smoothColor );
		else
			super();
	}


}
