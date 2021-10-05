package cerastes.pass;
import cerastes.shaders.DitherShader;
import h3d.Vector;


@ignore("shader")
class DitherPass extends h3d.pass.ScreenFx<DitherShader> {

	var ditherTable: h3d.mat.Texture;
	var palette: h3d.mat.Texture;

	public function new() {
		super(new DitherShader());

		ditherTable = hxd.Res.shd.psx_dither.toTexture();
		ditherTable.filter = Nearest;
		ditherTable.mipMap = None;
		//ditherTable.wrap = Repeat;

		//palette = hxd.Res.shd.palettealt_hsv.toTexture();
	}

	public function apply(  ctx : h3d.impl.RenderContext, src : h3d.mat.Texture, ?output : h3d.mat.Texture ) {

		//shader.palette=palette;
		shader.ditherPattern=ditherTable;
		shader.ditherPatternW=36;
		shader.ditherPatternH=4;
		shader.colors = 32;


		shader.texture = src;
		shader.textureW = src.width;
		shader.textureH = src.height;
		//shader.delta.set(1 / texture.width, 1 / texture.height);
		//render();

		if( output == null ) output = src;

		var isCube = src.flags.has(Cube);
		var faceCount = isCube ? 6 : 1;
		var tmp = ctx.textures.allocTarget(src.name+"DitherTmp", src.width, src.height, false, src.format, isCube);


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