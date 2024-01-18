package cerastes.c2d;


import cerastes.c2d.DebugDraw;
import cerastes.c2d.Vec2;
import h2d.col.Bounds;
import hxd.Event;
import hxd.res.DefaultFont;
import h2d.Object;
import cerastes.Entity.EntityManager;
import cerastes.macros.Callbacks.ClassKey;

@:keepSub
@:structInit class TileEntityDef
{

}


@:keepSub
abstract class TileEntity extends h2d.Object implements Entity
{


	// Interface
	#if tools
	//abstract public function getInspector() : Void;
	//abstract public function getEditorIcon() : Void;
	//abstract public function getDef() : TileEntityDef;
	#end

	public var initialized(get, null): Bool = false;

	function get_initialized() { return initialized; }

	public var lookupId: String;
	var destroyed = false;




	public function new(?parent: h2d.Object)
	{
		super( parent );
	}


	public function tick( delta: Float ) {

	}

	public function isDestroyed()
	{
		return destroyed;
	}

	public function destroy()
	{
		destroyed = true;
		remove();
	}

	//

	public function initialize( root: h2d.Object )
	{
		initialized = true;

	}


	public override function onAdd()
	{
		super.onAdd();

		if( initialized )
			EntityManager.instance.register(this);
	}

	public override function onRemove()
	{
		super.onRemove();
		destroyed = true;
	}

	function schedule(time: Float, func: Void->Void )
	{
		EntityManager.instance.schedule( hxd.Timer.elapsedTime + time, func );
	}
}