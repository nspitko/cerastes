package cerastes.pass;

import cerastes.shaders.ScanlineShader;
import cerastes.shaders.TransitionShader;
import h2d.filter.Filter;

import h2d.RenderContext.RenderContext;

class ScanlineFilter extends Filter {

	

	var pass : ScanlinePass;

	public function new(  ) {
		super();
		smooth = false;
		pass = new ScanlinePass();
	}



	override function draw( ctx : RenderContext, t : h2d.Tile ) {
		var out = ctx.textures.allocTarget("ScanlineScratch", cast t.width, cast t.height);
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
class ScanlinePass extends h3d.pass.ScreenFx<ScanlineShader> {

	var transitionTexture: h3d.mat.Texture;
	var phase: Float;

	public function new() {
		super(new ScanlineShader());

		transitionTexture = hxd.Res.shd.transition1.toTexture();
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
		var tmp = ctx.textures.allocTarget(src.name+"ScanlineTmp", src.width, src.height, false, src.format, isCube);

		
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