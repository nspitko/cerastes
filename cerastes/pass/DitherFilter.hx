package cerastes.pass;

import h2d.filter.Filter;

import h2d.RenderContext.RenderContext;

class DitherFilter extends Filter {

	

	var pass : DitherPass;

	public function new(  ) {
		super();
		smooth = false;
		pass = new DitherPass();
	}



	override function draw( ctx : RenderContext, t : h2d.Tile ) {
		var out = ctx.textures.allocTarget("DitherScratch", cast t.width, cast t.height);
		//var out = t.getTexture();
		var old = out.filter;
		out.filter = Linear;
		pass.apply(ctx, t.getTexture(), out);
		out.filter = old;
		@:privateAccess t.setTexture(out);
		return t;
	}

}