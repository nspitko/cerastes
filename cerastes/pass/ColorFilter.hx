package cerastes.pass;

#if hlimgui
import imgui.ImGui;
import imgui.ImGuiMacro.wref;
#end
import cerastes.shaders.TransitionShader;
import h2d.filter.Filter;
import h2d.RenderContext.RenderContext;
import cerastes.pass.SelectableFilter;

class ColorShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var r : Float = 0.0;
		@param var g : Float = 0.0;
		@param var b : Float = 0.0;

		function fragment()
		{
			var src = texture.get( calculatedUV );
			if( src.a == 0 )
				discard;

			pixelColor.r = r;
			pixelColor.g = g;
			pixelColor.b = b;
			pixelColor.a = src.a;

		}
	}

}

@:structInit class ColorFilterDef extends cerastes.fmt.CUIResource.CUIFilterDef
{
	@et("Float") public var r: Float = 0;
	@et("Float") public var g: Float = 0;
	@et("Float") public var b: Float = 0;
}

class ColorFilter extends Filter implements SelectableFilter
{
	public var pass : ColorPass;

	#if hlimgui
	@:keep public static function getEditorName() { return "\uf07c Color"; }
	@:keep public static function getDef() : ColorFilterDef { return {}; }
	@:keep public static function getInspector( def: ColorFilterDef ) {
		wref( ImGui.inputDouble("r",_,0.01,0.1), def.r );
		wref( ImGui.inputDouble("g",_,0.01,0.1), def.g );
		wref( ImGui.inputDouble("b",_,0.01,0.1), def.b );
	}
	#end

	public var r(get, set): Float;
	public var g(get, set): Float;
	public var b(get, set): Float;

	@:keep public function get_r() { return pass.r; }
	@:keep public function set_r( v ) { pass.r = v; return v; }

	@:keep public function get_g() { return pass.g; }
	@:keep public function set_g( v ) { pass.g = v; return v; }

	@:keep public function get_b() { return pass.b; }
	@:keep public function set_b( v ) { pass.b = v; return v; }

	public function new( ?def: ColorFilterDef  ) {
		super();
		smooth = false;
		pass = new ColorPass();

		if( def != null )
		{
			pass.r = def.r;
			pass.g = def.g;
			pass.b = def.b;
		}

	}

	override function draw( ctx : RenderContext, t : h2d.Tile ) {
		var out = ctx.textures.allocTarget("ColorScratch", cast t.width, cast t.height);
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
class ColorPass extends h3d.pass.ScreenFx<ColorShader> {

	public var r: Float;
	public var g: Float;
	public var b: Float;

	public function new() {
		super(new ColorShader());

		r = 0;
		g = 0;
		b = 0;
	}

	public function apply(  ctx : h3d.impl.RenderContext, src : h3d.mat.Texture, ?output : h3d.mat.Texture )
	{
		shader.r = r;
		shader.g = g;
		shader.b = b;

		shader.texture = src;

		if( output == null ) output = src;

		var isCube = src.flags.has(Cube);
		var faceCount = isCube ? 6 : 1;
		var tmp = ctx.textures.allocTarget(src.name+"ColorTmp", src.width, src.height, false, src.format, isCube);


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