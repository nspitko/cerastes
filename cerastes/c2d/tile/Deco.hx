package cerastes.c2d.tile;

import h2d.Tile;
import h2d.Bitmap;
import cerastes.Utils.*;

@:structInit class DecoDef extends cerastes.c2d.TileEntity.TileEntityDef
{
	@editor("Animation","Tile")
	public var anim: String = null;
}

@:build(cerastes.macros.EntityBuilder.build( DecoDef, "deco" ))
class Deco extends TileEntity
{
	// @todo: Some day move this to c2d where it belongs
	var anim: cerastes.ui.Anim;

	public override function initialize( root: h2d.Object )
	{
		var entry = Utils.getAtlasEntry( getDef().anim );

		anim = new cerastes.ui.Anim( entry != null ? entry : Utils.invalidAtlas(), this );
	}
}
