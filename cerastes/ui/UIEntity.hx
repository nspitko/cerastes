package cerastes.ui;

import hxd.res.DefaultFont;
import h2d.Object;
import cerastes.Entity.EntityManager;
import cerastes.macros.Callbacks.ClassKey;

class UIEntity extends h2d.Object implements Entity
{
	public var lookupId: String;
	var trackedCallbacks = new Array<(ClassKey -> Bool)>();
	var destroyed = false;

	var errorText: h2d.Text;

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

	/**
	 * Called when initialization fails due to a missing object.
	 */
	public function initError(err: String)
	{
		Utils.warning('$name failed to initialize: $err');
		errorText = new h2d.Text( DefaultFont.get(), this);
		errorText.text = err;
	}

	//

	public function initialize( root: h2d.Object )
	{
		if( errorText != null )
		{
			errorText.remove();
			errorText = null;
		}
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

	public function getTopmostParent()
	{
		var p: h2d.Object = this;
		while( p.parent != null ) p = p.parent;
		return p;
	}
}