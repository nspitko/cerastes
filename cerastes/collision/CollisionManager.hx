package cerastes.collision;

import cerastes.collision.Colliders.Collider;
import cerastes.collision.Colliders.AABB;
import cerastes.collision.Colliders.Circle;
import h2d.Graphics;
import cerastes.collision.Collision.CRaycast;
import cerastes.collision.Collision.CollisionMask;
import cerastes.collision.Collision.CRay;
import cerastes.collision.Collision.ColliderType;
import haxe.ds.Vector;
import cerastes.collision.Colliders.CollisionObject;
import cerastes.macros.Metrics;

/**
 * Broad phase spatial collision manager
 *
 * kinda dumb but whatever
 */
class CollisionManager
{
	//var collisionObjects: List<CollisionObject>;

	// LOL BROAD PHASE IS FOR SUCKERS
	// each bucket here maps to a collision type. We then loop through
	// each bucket ID, our "broad phase" is just throwing out buckets
	// that we're not interested in, then we iterate the few we do.
	// since >90% of our objects are bullets that only collide with
	// <10 entities at any given time... it's way less work than
	// we'd spend even building spatial buckets
	var objects: Array<CollisionObject>;

	public var debugGraphics: Graphics;

	public function new()
	{
		objects = [];
		debugGraphics = new Graphics();
	}

	public function insert( o: CollisionObject )
	{
		objects.push( o );
	}
	public function remove( o: CollisionObject )
	{
		objects.remove( o );
	}

	public function castRay( ray: CRay, mask: CollisionMask ): Array<CRaycast>
	{
		var out: Array<CRaycast> = [];
		/*
		for( collisionType in 0 ... buckets.length )
		{
			if( !mask.interactsWith( collisionType ) )
				continue;

			for( o in buckets[collisionType] )
			{
				Utils.error("STUB");
			}
		}
*/
		return out;
	}

	public function query( c: Collider, mask: CollisionMask ): Array<CollisionObject>
	{
		Metrics.begin();

		var out = new Array<CollisionObject>();


		// For everything in this bucket...
		for( other in objects )
		{
			if( !mask.interactsWith( other.collisionType ) )
				continue;


			// for each OTHER collider
			for( oc in other.colliders )
			{
				// If they intersect...
				//if( lc.intersects(oc, object.x, object.y, other.x, other.y) )
				if( c.intersects(oc, 0, 0, other.x, other.y, 0) )
				{
					out.push(other);
					break;
				}
			}


		}

		return out;


		Metrics.end();
	}

	public function tick( delta: Float )
	{
		Metrics.begin();

		if(Utils.SHOW_BULLET_AABBS)
		{
			if(debugGraphics.parent == null )
				cerastes.App.currentScene.s2d.addChild(debugGraphics);
			debugGraphics.clear();
			for( o in objects )
			{
				for(c in o.colliders )
				{
					switch( c.colliderType )
					{
						case Circle:
							var l: Circle = cast c;
							debugGraphics.lineStyle(1,0xFF4444);
							debugGraphics.drawCircle( o.x + l.p_x, o.y + l.p_y, l.r );
						case AABB:
							debugGraphics.lineStyle(1,0x44FF44);
							var l: AABB = cast c;
							debugGraphics.drawRect( o.x + l.min_x, o.y + l.min_y, l.max_x - l.min_x, l.max_y - l.min_y );

						default:
					}
				}
			}
		}

		// Array of collisions we've handled.
		var hashes = new Array<{a: CollisionObject, b: CollisionObject }>();

		// Loop over all collision type buckets
		for( object in objects  )
		{
			// For everything in this bucket...
			for( other in objects )
			{
				if( !object.collisionMask.interactsWith( other.collisionType ) )
					continue;


				// Don't interact with ourselves
				if( object == other )
					continue;


				var hasCollided = false;
				// for every positive collision hash.....
				for(hash in hashes )
				{
					// skip if we've already handled this collision
					if( ( hash.a == object || hash.b == object ) &&
						( hash.a == other || hash.b == other ) )
					{
						hasCollided = true;
						break;
					}

				}


				//if( hasCollided ) continue;


				// for each collider
				for( lc in object.colliders )
				{
					// for each OTHER collider
					for( oc in other.colliders )
					{
						// If they intersect...
						//if( lc.intersects(oc, object.x, object.y, other.x, other.y) )
						if( lc.intersects(oc, object.x, object.y, other.x, other.y, 0) )
						{
							hasCollided = true;
							object.handleCollision(other);
							other.handleCollision(object);
							hashes.push({a:object, b:other});
							break;
						}
					}
					if( hasCollided )
						break;
				}
			}
		}

		Metrics.end();
	}
}
