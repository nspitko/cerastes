package cerastes.pass;

import h2d.RenderContext;
import h3d.mat.Texture;
import h2d.Bitmap;
import h2d.filter.Mask;
import h2d.filter.Filter;

#if hlimgui
import cerastes.tools.ImguiTools.ImGuiTools;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import cerastes.macros.MacroUtils.imTooltip;
#end


@:structInit class MaskFilterDef extends cerastes.fmt.CUIResource.CUIFilterDef
{
	@cd_type("Texture") public var texture: String = null;
}

@:keep
class MaskFilter extends Filter implements SelectableFilter
{
	#if hlimgui
	@:keep public static function getEditorName() { return "\uf07c Mask"; }
	@:keep public static function getDef() : MaskFilterDef { return {}; }
	@:keep public static function getInspector( def: MaskFilterDef ) {
		var t: String = ImGuiTools.inputTexture("Texture",def.texture);
		if( t != null )
			def.texture = t;

	}
	#end

	public var pass : MaskPass;

	public var texture(get, set): Texture;

	@:keep public function get_texture() { return @:privateAccess pass.maskTexture; }
	@:keep public function set_texture( v ) {
		@:privateAccess pass.maskTexture = v;
		//v.filter = Nearest;
		v.mipMap = None;
		return v;
	}

	public function new( ?def: MaskFilterDef  ) {
		super();
		var t = Utils.resolveTexture( def.texture );
		pass = new MaskPass( t );
		smooth = false;
		this.texture = t;

	}



	override function draw( ctx : RenderContext, t : h2d.Tile ) {
		var out = ctx.textures.allocTarget("MaskScratch", cast t.width, cast t.height);

		var old = out.filter;
		out.filter = Linear;
		pass.apply(ctx, t.getTexture(), out);
		out.filter = old;
		@:privateAccess t.setTexture(out);
		return t;
	}

}

@ignore("shader")
class MaskPass extends h3d.pass.ScreenFx<MaskShader> {

	var maskTexture: h3d.mat.Texture;

	public function new( tex: h3d.mat.Texture) {
		super(new MaskShader());

		maskTexture = tex;
		maskTexture.mipMap = None;
	}

	public function apply(  ctx : h3d.impl.RenderContext, src : h3d.mat.Texture, ?output : h3d.mat.Texture ) {

		shader.maskTexture=maskTexture;
		shader.texture = src;

		if( output == null ) output = src;

		var isCube = src.flags.has(Cube);
		var faceCount = isCube ? 6 : 1;
		var flags = isCube ? [ h3d.mat.Data.TextureFlags.Cube ] : null;
		var tmp = ctx.textures.allocTarget(src.name+"MaskTmp", src.width, src.height, false, src.format, flags);


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

class MaskShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var maskTexture : Sampler2D;
		@param var phase : Float;


		function fragment()
		{

			 // sample the texture and convert to YUV color space
			var src = texture.get( calculatedUV );
			var mask = maskTexture.get( calculatedUV );

			pixelColor = mask.a > 0.5 ? src : vec4(0,0,0,0);
		}
	}

}