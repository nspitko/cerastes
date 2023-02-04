package cerastes.pass;

import cerastes.shaders.TransitionShader;
import h2d.filter.Filter;

import h2d.RenderContext.RenderContext;

class SubtractionShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var amount : Float;

		function fragment()
		{
			var src = texture.get( calculatedUV );
			pixelColor = src - amount;
			pixelColor.a = src.a;
		}
	}

}

class SubtractionFilter extends Filter
{
	public var pass : SubtractionPass;

	public function new(  ) {
		super();
		smooth = false;
		pass = new SubtractionPass();

	}

	override function draw( ctx : RenderContext, t : h2d.Tile ) {
		var out = ctx.textures.allocTarget("SubtractionScratch", cast t.width, cast t.height);
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
class SubtractionPass extends h3d.pass.ScreenFx<SubtractionShader> {

	public var amount: Float;

	public function new() {
		super(new SubtractionShader());

		amount = 0;
	}

	public function apply(  ctx : h3d.impl.RenderContext, src : h3d.mat.Texture, ?output : h3d.mat.Texture )
	{
		shader.amount = amount;
		shader.texture = src;

		if( output == null ) output = src;

		var isCube = src.flags.has(Cube);
		var faceCount = isCube ? 6 : 1;
		var tmp = ctx.textures.allocTarget(src.name+"SubtractionTmp", src.width, src.height, false, src.format, isCube);


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