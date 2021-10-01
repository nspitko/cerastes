package cerastes;

import cerastes.fmt.BulletLevelResource.CBLPoint;
import cerastes.fmt.BulletLevelResource.CBLFile;
import h2d.Object;
import cerastes.fmt.BulletLevelResource.CBLObject;

@:structInit
class CBLObject
{
	public var type: String;
	public var position: CBLPoint;
	public var spawnPosition: CBLPoint;
	public var fiber: String; // Optional fiber to run. Must be a CannonEntity
}

class BulletLevel extends h2d.Object
{
	var objects: haxe.ds.GenericStack<CBLObject>;
	var objectIndex: Int = 0;
	var timer: Float;

	var levelData: CBLFile;
	var spawnPosition: CBLPoint;

	// @todo make this configerable.
	var viewportWidth: Int = 640;

	var velocityX: Float;
	var velocityY: Float;

	public function new( data: CBLFile, ?parent: Object )
	{
		super(parent);
		levelData = data;

		if( data == null ) return;

		for( d in data.objects )
		{
			objects.add({
				type: d.type,
				position: d.position,
				spawnPosition: d.position,
				fiber: d.fiber
			});
		}

		// Now do spawn groups.
		for( g in data.spawnGroups )
		{
			for( d in g.objects )
			{
				objects.add({
					type: d.type,
					position: d.position,
					spawnPosition: g.spawnPosition,
					fiber: d.fiber
				});
			}
		}

		//haxe.ds.ListSort.sortSingleLinked(objects.head, function(a, b): Int{ return cast a.elt.spawnPosition - b.elt.spawnPosition; });
	}

	public function tick( delta: Float )
	{
		timer += delta;
		var pos = viewportWidth + x;



		//spawnPosition = pos;
	}

	function spawnObject(o: CBLObject)
	{

	}
}