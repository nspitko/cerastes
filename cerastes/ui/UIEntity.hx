package cerastes.ui;

import h2d.col.Bounds;
import hxd.Event;
import hxd.res.DefaultFont;
import h2d.Object;
import cerastes.Entity.EntityManager;
import cerastes.macros.Callbacks.ClassKey;

class UIEntity extends h2d.Object implements Entity
{
	// Statics
	public static var draggingEntity: UIEntity;
	public static var draggingTarget: UIEntity;

	public function queryDrag( bounds: Bounds )
	{
		if( draggingEntity == null )
			return false;

		var dragBounds = draggingEntity.getBounds();
		if( getBounds().intersects( dragBounds ) )
		{
			draggingTarget = this;
			return true;
		}

		if( draggingTarget == this )
			draggingTarget = null;

		return false;
	}

	// -----------------------------------------------------------------


	public var lookupId: String;
	var trackedCallbacks = new Array<(ClassKey -> Bool)>();
	var destroyed = false;

	var errorText: h2d.Text;
	var postInit: Bool = false;

	// Dragdrop
	var dragInteractive: h2d.Interactive;
	var dragCallback: ( Event ) -> Void;
	var dragStartX: Float;
	var dragStartY: Float;

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


	public function tick( delta: Float ) {
		if( !postInit && getScene() != null )
		{
			postInit = true;
			onAfterInitialize();
		}
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

	public function registerDrag( int: h2d.Interactive, cb: ( Event ) -> Void )
	{
		dragInteractive = int;
		dragInteractive.onPush = onDragStart;
		dragCallback = cb;
	}


	public function onDragStart( e: Event )
	{
		dragStartX = x;
		dragStartY = y;

		dragInteractive.startCapture( ( e ) -> {

			if( e.kind == ERelease || e.kind == EReleaseOutside )
			{
				dragInteractive.stopCapture();
				return;
			}

			if( e.kind != EMove )
				return;

			dragCallback( e );

		}, onDragEnd );

		UIEntity.draggingEntity = this;
	}

	public function onDragEnd()
	{
		if( draggingTarget != null )
			draggingTarget.onDrop( this );

		x = dragStartX;
		y = dragStartY;

		var flow = Std.downcast(parent, h2d.Flow);
		if( flow != null )
			flow.reflow();
	}

	public function onDrop( other: UIEntity )
	{

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