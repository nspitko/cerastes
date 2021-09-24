package cerastes.collision;

import game.GameState.CollisionGroup;
import cerastes.collision.Collision.ColliderType;
import haxe.ds.Vector;
import cerastes.collision.Colliders.CollisionObject;

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
	var buckets: haxe.ds.Vector<List<CollisionObject>>;

	public function new()
	{
		buckets = new Vector(CollisionGroup.Max);
		for( i in 0 ... CollisionGroup.Max )
			buckets[i] = new List<CollisionObject>();

	}

	public function insert( o: CollisionObject )
	{
		buckets[ o.collisionType ].add( o );
	}

	public function tick( delta: Float )
	{
		// Array of collisions we've handled.
		var hashes = new Array<{a: CollisionObject, b: CollisionObject }>();

		// Loop over all collision type buckets
		for( collisionType in 0 ... buckets.length )
		{
			var bucket = buckets[collisionType];
			// For everything in this bucket...
			for( object in bucket )
			{
				var checkHashes = false;
				// for every positive collision hash....
				for(hash in hashes )
				{
					// If one of them is us, check hashes for every OTHER object later.
					if( hash.a == object || hash.b == object )
						checkHashes = true;
				}
				// for every collision type (again)
				for( otherType in 0 ... buckets.length )
				{
					// If we interact with the other type...
					if( object.collisionMask.interactsWith( otherType ) )
					{
						// for everything in this other bucket...
						for( other in buckets[otherType])
						{
							// Don't interact with ourselves
							if( object == other )
								continue;

							var hasCollided = false;
							// If we've collided with something already...
							if( checkHashes )
							{
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
							}

							if( hasCollided ) continue;


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
				}
			}
		}
	}
}
