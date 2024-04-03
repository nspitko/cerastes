package cerastes.pass;

import cerastes.shaders.CircleDisintegrateShader;
import h2d.filter.Filter;

import h2d.RenderContext.RenderContext;

class CircleDisintegrateFilter extends Filter {


	var pass : h3d.pass.ScreenFx<CircleDisintegrateShader>;

	public var time(get, set) : Float;
	inline function get_time() return pass.shader.time;
	inline function set_time(v: Float) return pass.shader.time = v ;

	public var color1(get, set) : hxsl.Types.Vec4;
	inline function get_color1() return pass.shader.color1;
	inline function set_color1(v) return pass.shader.color1 = v;

	public var color2(get, set) : hxsl.Types.Vec4;
	inline function get_color2() return pass.shader.color2;
	inline function set_color2(v) return pass.shader.color2 = v;

	public var shrinkSpeed(get, set) : Float;
	inline function get_shrinkSpeed() return pass.shader.shrinkSpeed;
	inline function set_shrinkSpeed(v) return pass.shader.shrinkSpeed = v;

	public var lineSpeed(get, set) : Float;
	inline function get_lineSpeed() return pass.shader.lineSpeed;
	inline function set_lineSpeed(v) return pass.shader.lineSpeed = v;

	public var fadeSpeed(get, set) : Float;
	inline function get_fadeSpeed() return pass.shader.fadeSpeed;
	inline function set_fadeSpeed(v) return pass.shader.fadeSpeed = v;

	public var w(get, set) : Float;
	inline function get_w() return pass.shader.w;
	inline function set_w(v) return pass.shader.w = v;

	public function new(  ) {
		super();
		smooth = false;
		pass = new h3d.pass.ScreenFx(new CircleDisintegrateShader());

		pass.shader.color1.set(0.867, 0.675, 0.557, 1.0);
		pass.shader.color2.set(0.871, 0.843, 0.804, 1.0);
		pass.shader.w = 0.008;
		pass.shader.lineSpeed = 1.4;
		pass.shader.fadeSpeed = 1.8;
		pass.shader.shrinkSpeed = 1.5;

		pass.shader.time = 0;
	}



	override function draw( ctx : RenderContext, t : h2d.Tile ) {


		pass.shader.textureW = t.width;
		pass.shader.textureH = t.height;


		var out = ctx.textures.allocTileTarget("maskTmp", t);
		ctx.engine.pushTarget(out);
		pass.shader.texture = t.getTexture();

		pass.render();
		ctx.engine.popTarget();
		return h2d.Tile.fromTexture(out);
	}

}