package cerastes.ui;

import cerastes.c2d.DebugDraw;
import cerastes.c2d.Vec2;
import h2d.col.Bounds;
import hxd.Event;
import hxd.res.DefaultFont;
import h2d.Object;
import cerastes.Entity.EntityManager;
import cerastes.macros.Callbacks.ClassKey;

class UIEntity extends h2d.Object implements Entity
{
	// Statics
	static var draggingEntity: UIEntity;
	static var draggingEntityKey: Int = -1;
	public static var draggingTarget: UIEntity;

	public var initialized(get, null): Bool = false;

	function get_initialized() { return initialized; }

	public function beginDrag( entity: UIEntity, ?key: Int = -1, ?bounds: Bounds = null)
	{
		draggingEntity = entity;
		draggingEntityKey = key;
	}
	/**
	 * For key, create your own int enum to pass into here if you want to
	 * disambiguate multiple drag sources
	 *
	 * @param bounds
	 * @param key
	 */
	public function queryDrag( bounds: Bounds, key: Int = -1 )
	{
		if( draggingEntity == null )
			return false;

		if( key != draggingEntityKey && key != -1 )
			return false;

		var dragBounds = draggingEntity.getDragBounds();
		if( dragBounds.intersects( bounds ) )
		{
			//DebugDraw.bounds( dragBounds );
			//DebugDraw.bounds( bounds, 0x00FF00 );

			draggingTarget = this;
			return true;
		}

		if( draggingTarget == this )
			draggingTarget = null;

		return false;
	}

	public function getDragBounds()
	{
		return getBounds();
	}

	public function queryDragPoint( point: Vec2, key: Int = -1 )
	{
		var b = new Bounds();
		b.addPoint( point );
		point.x++;
		point.y++;
		b.addPoint( point );
		//DebugDraw.bounds( b, 0x0000FF);
		return queryDrag( b, key );
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
	var dragKey: Int;

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

	public function registerDrag( int: h2d.Interactive, cb: ( Event ) -> Void, ?dragKey: Int = -1 )
	{
		dragInteractive = int;
		dragInteractive.onPush = onDragStart;
		dragCallback = cb;
		this.dragKey = dragKey;
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
		UIEntity.draggingEntityKey = dragKey;
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
			return;
		}

		initialized = true;

	}

	function trackCallback( success: Bool, unregisterFunction: ( ClassKey -> Bool ) )
	{
		if( success )
			trackedCallbacks.push( unregisterFunction );
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