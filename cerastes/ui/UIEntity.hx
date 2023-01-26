package cerastes.ui;

import h2d.Object;
import cerastes.Entity.EntityManager;
import cerastes.macros.Callbacks.ClassKey;

class UIEntity extends h2d.Object implements Entity
{
	public var lookupId: String;
	var trackedCallbacks = new Array<(ClassKey -> Bool)>();
	var destroyed = false;

	#if tools
	public static function getEditorIcon()
	{
		return "\uf07c";
	}
	#end

	public function new()
	{
		super();
	}


	public function tick( delta: Float ) {}

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

	}

	function trackCallback( success: Bool, unregisterFunction: ( ClassKey -> Bool ) )
	{
		if( success )
			trackedCallbacks.push( unregisterFunction );
	}

	public override function onAdd()
	{
		super.onAdd();
		EntityManager.instance.register(this);
	}

	public override function onRemove()
	{
		super.onRemove();
		destroyed = true;

		for( cb in trackedCallbacks )
            cb( this );
	}

}