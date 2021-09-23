package cerastes.collision;

import game.GameState.CollisionGroup;
import quadtree.CollisionAreaType;
import quadtree.types.Collider;
import quadtree.types.Rectangle;

abstract CollisionMask(Int) from Int to Int {
	inline public function new(i:Int) {
		this = i;
	}

	public function interactsWith(other: CollisionGroup )
	{
		return ( this | ( 1 << other ) ) != 0;
	}
}

interface CollisionObject
{
	// Collision is just mask | type, so a bullet
	public var collisionMask: CollisionMask;	// Things that can interact with me
	public var collisionType: CollisionGroup;	// My interaction type

	public var colliders(default, null): haxe.ds.Vector<Collider>;
	public dynamic function onCollision( other: CollisionObject ) : Void;
}

interface CollisionHull extends Collider
{
	public var owner(default, null): CollisionObject;
}


class Box implements Rectangle implements CollisionHull
{
	// Value denoting the object's type, to avoid reflection calls
    // for better performance.
    public var areaType: CollisionAreaType = CollisionAreaType.Rectangle;

    // Use this to temporarily disable an object's collision
    // without removing it from whatever list it may be in.
    public var collisionsEnabled: Bool = true;

    public var x: Float;
    public var y: Float;
    public var width: Float;
    public var height: Float;

	public var angle: Float;

	// CollisionObject
	public var owner: CollisionObject;

	public function new( owner: CollisionObject, width: Float, height: Float)
	{
		this.owner = owner;
		this.width = width;
		this.height = height;
	}

    public function onOverlap(collider: Collider)
    {
		var other: CollisionHull = cast collider;
		if( !owner.collisionMask.interactsWith( other.owner.collisionType ) ) return;

		owner.onCollision( other.owner );
    }

	/**
        Called by `Physics.separate()` with the movement that should be applied to this oobject
        on each axis in order to separate from another colliding object.
    **/
    public function moveToSeparate(deltaX: Float, deltaY: Float)
	{
		// idk lol
	}
}

class Circle implements quadtree.types.Circle implements CollisionHull
{
	// Value denoting the object's type, to avoid reflection calls
    // for better performance.
    public var areaType: CollisionAreaType = CollisionAreaType.Circle;

    // Use this to temporarily disable an object's collision
    // without removing it from whatever list it may be in.
    public var collisionsEnabled: Bool = true;

    public var centerX: Float;
    public var centerY: Float;
    public var radius: Float;


	// CollisionObject
	public var owner: CollisionObject;

	public function new( owner: CollisionObject, radius: Float)
	{
		this.owner = owner;
		this.radius = radius;
	}

    public function onOverlap(collider: Collider)
    {
		var other: CollisionHull = cast collider;
		if( !owner.collisionMask.interactsWith( other.owner.collisionType ) ) return;

		owner.onCollision( other.owner );
    }

	/**
        Called by `Physics.separate()` with the movement that should be applied to this oobject
        on each axis in order to separate from another colliding object.
    **/
    public function moveToSeparate(deltaX: Float, deltaY: Float)
	{
		// idk lol
	}
}