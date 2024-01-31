package cerastes.pass;
import cerastes.shaders.CircleDisintegrateShader;
import h3d.Vector4;


@ignore("shader")
class CircleDisintegratePass extends h3d.pass.ScreenFx<CircleDisintegrateShader> {

	var palette: h3d.mat.Texture;

	public var time(get, set) : Float;
	inline function get_time() return shader.time;
	inline function set_time(v) return shader.time = v;

	public var color1(get, set) : hxsl.Types.Vec;
	inline function get_color1() return shader.color1;
	inline function set_color1(v) return shader.color1 = v;

	public var color2(get, set) : hxsl.Types.Vec;
	inline function get_color2() return shader.color2;
	inline function set_color2(v) return shader.color2 = v;

	public var shrinkSpeed(get, set) : Float;
	inline function get_shrinkSpeed() return shader.shrinkSpeed;
	inline function set_shrinkSpeed(v) return shader.shrinkSpeed = v;

	public var lineSpeed(get, set) : Float;
	inline function get_lineSpeed() return shader.lineSpeed;
	inline function set_lineSpeed(v) return shader.lineSpeed = v;

	public var fadeSpeed(get, set) : Float;
	inline function get_fadeSpeed() return shader.fadeSpeed;
	inline function set_fadeSpeed(v) return shader.fadeSpeed = v;

	public var w(get, set) : Float;
	inline function get_w() return shader.w;
	inline function set_w(v) return shader.w = v;

	public function new() {
		super(new CircleDisintegrateShader());

		shader.color1.set(0.867, 0.675, 0.557, 1.0);
		shader.color2.set(0.871, 0.843, 0.804, 1.0);
		shader.w = 0.008;
		shader.lineSpeed = 0.2;
		shader.fadeSpeed = 1.0;
		shader.shrinkSpeed = 0.7;

		shader.time = 0;

	}

	public function apply(  ctx : h3d.impl.RenderContext, src : h3d.mat.Texture, ?output : h3d.mat.Texture ) {


		shader.texture = src;
		shader.textureW = src.width;
		shader.textureH = src.height;




		if( output == null ) output = src;

		var isCube = src.flags.has(Cube);
		var faceCount = isCube ? 6 : 1;
		var tmp = ctx.textures.allocTarget(src.name+"DitherTmp", src.width, src.height, false, src.format, isCube);


		for(i in 0 ... faceCount){
			engine.pushTarget(tmp, i);
			//render();
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