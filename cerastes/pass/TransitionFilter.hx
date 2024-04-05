package cerastes.pass;

import h3d.mat.Texture;
#if hlimgui
import cerastes.tools.ImguiTools.ImGuiTools;
import imgui.ImGui;
import imgui.ImGuiMacro.wref;
#end

import cerastes.shaders.TransitionShader;
import h2d.filter.Filter;

import h2d.RenderContext.RenderContext;

@:structInit class TransitionFilterDef extends cerastes.fmt.CUIResource.CUIFilterDef
{
	@cd_type("Float") public var amount: Float = 0;
	@cd_type("Texture") public var texture: String = null;
}

class TransitionFilter extends Filter  implements SelectableFilter
{
	#if hlimgui
	@:keep public static function getEditorName() { return "\uf07c Transition"; }
	@:keep public static function getDef() : TransitionFilterDef { return {}; }
	@:keep public static function getInspector( def: TransitionFilterDef ) {
		wref( ImGui.inputDouble("amount",_,0.01,0.1), def.amount );
		var t: String = ImGuiTools.inputTexture("Texture",def.texture,"shd");
		if( t != null )
			def.texture = t;
	}
	#end

	public var pass : TransitionPass;

	public var amount(get, set): Float;
	public var texture(get, set): Texture;

	@:keep public function get_amount() { return pass.phase; }
	@:keep public function set_amount( v ) { pass.phase = v; return v; }

	@:keep public function get_texture() { return @:privateAccess pass.transitionTexture; }
	@:keep public function set_texture( v ) {
		@:privateAccess pass.transitionTexture = v;
		v.filter = Nearest;
		v.mipMap = None;
		return v;
	}

	public function new( ?def: TransitionFilterDef  ) {
		super();
		smooth = false;
		pass = new TransitionPass();

		if( def != null )
		{
			amount = def.amount;
			texture = Utils.resolveTexture( def.texture );
		}
	}



	override function draw( ctx : RenderContext, t : h2d.Tile ) {
		var out = ctx.textures.allocTarget("TransitionScratch", cast t.width, cast t.height);
		//var out = t.getTexture();
		var old = out.filter;
		out.filter = Linear;
		pass.apply(ctx, t.getTexture(), out);
		out.filter = old;
		@:privateAccess t.setTexture(out);
		return t;
	}

}

@ignore("shader")
class TransitionPass extends h3d.pass.ScreenFx<TransitionShader> {

	var transitionTexture: h3d.mat.Texture;
	public var phase: Float;

	public function new() {
		super(new TransitionShader());

		//transitionTexture = hxd.Res.shd.transition1.toTexture();
		transitionTexture.filter = Nearest;
		transitionTexture.mipMap = None;
		phase = 0;
		//ditherTable.wrap = Repeat;

		//palette = hxd.Res.shd.palettealt_hsv.toTexture();
	}

	public function apply(  ctx : h3d.impl.RenderContext, src : h3d.mat.Texture, ?output : h3d.mat.Texture ) {

		//shader.palette=palette;
		shader.transitionTexture=transitionTexture;


		shader.texture = src;
		shader.phase = phase;
		//shader.delta.set(1 / texture.width, 1 / texture.height);
		//render();

		if( output == null ) output = src;

		var isCube = src.flags.has(Cube);
		var faceCount = isCube ? 6 : 1;
		var flags = isCube ? [ h3d.mat.Data.TextureFlags.Cube ] : null;
		var tmp = ctx.textures.allocTarget(src.name+"TransitionTmp", src.width, src.height, false, src.format, flags);


		for(i in 0 ... faceCount){
			engine.pushTarget(tmp, i);
			render();
			engine.popTarget();
		}



		var outDepth = output.depthBuffer;
		output.depthBuffer = null;
		for( i in 0 ... faceCount ){
			engine.pushTarget(output, i);
			render();
			engine.popTarget();
		}
		output.depthBuffer = outDepth;
	}

}