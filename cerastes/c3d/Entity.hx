package cerastes.c3d;

import cerastes.c3d.Vec3;
import h3d.Vector;
import h3d.col.Point;
import h3d.scene.Object;

// Shim
#if q3bsp
@:structInit class EntityData extends cerastes.c3d.q3bsp.Q3BSPEntity.Q3BSPEntityData {}
#else #if q3map
@:structInit class EntityData extends QEntityData {}
#else
@:structInit class EntityData extends EntityDataBase {}
#end #end


@:keepSub
@:structInit
class EntitySubclassData
{
	public var base: String = null;
	public var cls: String = null;
}


@:structInit
class EntityDataBase #if hxbit implements hxbit.Serializable #end
{
	@:s public var props: Map<String, String> = [];

	public function getProperty( key: String, defaultVal: String = null )
	{
		if( props.exists( key ) )
			return props[key];
		return defaultVal;
	}

	public function getPropertyInt(key: String, defaultVal: Int = 0 )
	{
		if( props.exists( key ) )
			return Std.parseInt( props[key] );
		return defaultVal;
	}

	public function getPropertyFloat(key: String, defaultVal: Float = 0 )
	{
		if( props.exists( key ) )
			return Std.parseFloat( props[key] );
		return defaultVal;
	}

	public function getPropertyPoint(key: String, defaultVal: Point = null )
	{
		if( props.exists( key ) )
		{
			var bits = props[key].split(" ");
			return new h3d.col.Point(
				Std.parseFloat(bits[0]),
				Std.parseFloat(bits[1]),
				Std.parseFloat(bits[2])
			);
		}
		return defaultVal;
	}
}

// Shim
#if q3bsp
class Entity extends cerastes.c3d.q3bsp.Q3BSPEntity {}
#else #if q3map
class Entity extends QEntity {}
#else
class Entity extends BaseEntity {}
#end #end

@:subClass("cerastes.c3d.SubclassData")
@:keepSub
@:keepInit
class BaseEntity extends Object implements cerastes.Entity
{
	public var lookupId: String;

	var spawnFlags : Int;

	var destroyed = false;
	public var world(get, null): cerastes.c3d.World;
	#if bullet
	public var body: cerastes.c3d.BulletBody = null;
	public var bodyOrigin = new Vec3(0,0,0);
	public var bodyOffset = new Vec3(0,0,0);
	#end

	//@:noCompletion var subclassData: EntitySubclassData;

	public function get_world() : cerastes.c3d.World
	{
		return world;
	}

	// This is a function instead of a property for dumb haxe reasons
	public function isDestroyed() { return destroyed; }

	// ---------------------------------------------------------------------------------------------------------------
	// Action stubs. These are designed to be overriden by leaves
	function onCreated( def: EntityData ) { }
	function onInput( source: Entity, port: String ) {}

	// ---------------------------------------------------------------------------------------------------------------
	public function destroy() {

		if( body != null )
			body.remove();

		destroyed = true;
	}

	// ---------------------------------------------------------------------------------------------------------------
	public function tick( delta: Float )
	{
		// Slam position with body position
		if( body != null )
			body.sync();

		#if hlimgui
		imguiUpdate();
		#end
	}

	// ---------------------------------------------------------------------------------------------------------------
	#if hlimgui
	function imguiUpdate() {}
	#end

	// ---------------------------------------------------------------------------------------------------------------
	function create( def: EntityData, w: World )
	{
		//ensureSubclassData();
		world = w;
		createBody(def);
/*
		if( def.spawnType == EST_ENTITY )
		{
			var origin = def.getPropertyPoint('origin');
			if( origin != null )
			{
				setPosition(
					-origin.x,
					origin.y,
					origin.z
				);
			}
			// Common properties
			targetName = def.getProperty("targetname");
			angle = def.getPropertyFloat("angle");
			spawnFlags = def.getPropertyInt("spawnflags");
		}
*/


		onCreated(def);

		initializeBody();

		world.entityManager.register(this);

	}

	// ---------------------------------------------------------------------------------------------------------------
	// entity IO
	// ---------------------------------------------------------------------------------------------------------------
	function fireOutput( target: String, port: String )
	{
		for( e in world.entityManager.entities )
		{
			var q: Entity = cast e;
			if( q.name == target )
				q.fireInput( cast this, port );
		}
	}

	public function fireInput( source: Entity, port: String )
	{
		onInput( source, port );
	}

	// ---------------------------------------------------------------------------------------------------------------
	// Physics
	// ---------------------------------------------------------------------------------------------------------------
	#if bullet
	function onCollide( manifold: bullet.Native.PersistentManifold, body: BulletBody, other: Entity, otherBody: BulletBody ) {}

	/**
	 * Called during create.
	 * @param def
	 */
	function createBody( def: EntityData ) {}

	/**
	 * Called during create, after createBody. Useful for body agnostic setup like moving the body.
	 */
	function initializeBody()
	{

	}

	// ---------------------------------------------------------------------------------------------------------------
	function collide( manifold: bullet.Native.PersistentManifold, body: BulletBody, other: Entity, otherBody: BulletBody )
	{
		onCollide( manifold, body, other, otherBody );
	}
	#end

	// ---------------------------------------------------------------------------------------------------------------
	public function setAbsOrigin( x : Float, y : Float, z : Float )
	{
		setPosition(x,y,z);
		#if bullet
		if( body != null )
		{
			body.setTransform( new bullet.Point(x,y,z) );
			bodyOrigin.set( x + bodyOffset.x, y + bodyOffset.y, z + bodyOffset.z);
		}
		#end
	}

	// ---------------------------------------------------------------------------------------------------------------
	public function setBodyOrigin( x : Float, y : Float, z : Float )
	{
		if( #if !bullet true || #end Utils.assert( body != null, "Tried to set body origin on entity without a body!" ) )
		{
			setAbsOrigin(x,y,z);
			return;
		}
		#if bullet
		setAbsOrigin( x - bodyOffset.x, y - bodyOffset.y, z - bodyOffset.z );
		#end
	}

	// ---------------------------------------------------------------------------------------------------------------
	public function getBodyOrigin() : h3d.Vector
	{
		if( #if !bullet true || #end Utils.assert( body != null, "Tried to set body origin on entity without a body!" ) )
		{
			return new Vector(x,y,z);
		}
		#if bullet
		return bodyOrigin;
		#end
	}

	// ---------------------------------------------------------------------------------------------------------------
	// Useful debug stuff
	// ---------------------------------------------------------------------------------------------------------------
	@:access( cerastes.c3d.BulletBody )
	public function debugDrawBody( body: BulletBody, duration: Float = 0, color = 0xFF0000, alpha = 0.25, thickness=1.0 )
	{
		var shape = body.inst.getCollisionShape();
		var t = body.inst.getWorldTransform();
		var min = new bullet.Native.Vector3();
		var max = new bullet.Native.Vector3();
		shape.getAabb(t,min,max);


		// make points
		var p = [
			new h3d.col.Point(min.x(), min.y(), min.z()),
			new h3d.col.Point(max.x(), min.y(), min.z()),
			new h3d.col.Point(min.x(), max.y(), min.z()),
			new h3d.col.Point(min.x(), min.y(), max.z()),
			new h3d.col.Point(max.x(), max.y(), min.z()),
			new h3d.col.Point(max.x(), min.y(), max.z()),
			new h3d.col.Point(min.x(), max.y(), max.z()),
			new h3d.col.Point(max.x(), max.y(), max.z()),
		];
		var idx = new Array<Int>();
		idx.push(0); idx.push(1); idx.push(5);
		idx.push(0); idx.push(5); idx.push(3);
		idx.push(1); idx.push(4); idx.push(7);
		idx.push(1); idx.push(7); idx.push(5);
		idx.push(3); idx.push(5); idx.push(7);
		idx.push(3); idx.push(7); idx.push(6);
		idx.push(0); idx.push(6); idx.push(2);
		idx.push(0); idx.push(3); idx.push(6);
		idx.push(2); idx.push(7); idx.push(4);
		idx.push(2); idx.push(6); idx.push(7);
		idx.push(0); idx.push(4); idx.push(1);
		idx.push(0); idx.push(2); idx.push(4);

		var i =0;
		while( i < idx.length )
		{
			var index =  idx[i];
			var indexNext =  idx[i+1];
			DebugDraw.line( p[ index ] , p[ indexNext ], color, duration, alpha );
			i++;
			if( i % 3 == 2 ) i++;
		}
	}
}