package cerastes;
import h2d.col.Point;
import cerastes.Utils.*;
import h2d.col.Bounds;

interface Collidable
{
	public var aabb:Bounds;
	public var position: Point;
	public var active: Bool;
}

class CollisionManager
{
	public static var instance(default, null):CollisionManager = new CollisionManager();

	var objects = new Array<Collidable>();

	public function new()
	{

	}

	public function register( other: Collidable )
	{
		objects.push( other );
	}

	public function unregister( other: Collidable )
	{
		assert( objects.remove( other ), "Tried to unregister a collidable but it couldn't be found.");
	}

	public function getCollidesWith( actor: Collidable ) : Array<Collidable>
	{
		var out = new Array<Collidable>();
		// @todo: This is the dumbest solution
		for( other in this.objects )
		{
			if( other.active && intersects( actor, other ) )
				out.push( other );
		}

		return out;
	}

	public inline function intersects( a: Collidable, b: Collidable )
	{
		return !( 
			b.position.x > a.position.x + a.aabb.xMax  ||
			b.position.x + b.aabb.xMax < a.position.x ||
			b.position.y > a.position.y + a.aabb.yMax ||
			b.position.y + b.aabb.yMax < a.position.y );
	}

	public function bCollides( actor: Collidable )
	{
		return getCollidesWith( actor ).length > 0;
	}
}