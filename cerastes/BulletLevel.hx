package cerastes;

#if cannonml

import cerastes.butai.ButaiNodeManager;
import cerastes.InputManager.InputListener;
import cerastes.InputManager.InputButton;
import cerastes.InputManager.InputState;
import cerastes.fmt.BulletLevelResource.CBLMesh;
import cerastes.fmt.BulletLevelResource.CBLTrigger;
import cerastes.fmt.BulletLevelResource.CBLTriggerType;
import cerastes.bulletml.CannonBullet;
import cerastes.bulletml.BulletManager;
import cerastes.collision.Colliders.AABB;
import cerastes.fmt.BulletLevelResource.CBLPoint;
import cerastes.fmt.BulletLevelResource.CBLFile;
import h2d.Object;
import cerastes.fmt.BulletLevelResource.CBLObject;

import db.Butai;

@:structInit


class BulletLevel extends h2d.Object
{
	var objectIndex: Int = 0;
	var timer: Float;

	var levelData: CBLFile;
	var spawnPosition: CBLPoint;

	// @todo make this configerable.
	var viewportWidth: Int = 360;
	var viewportHeight: Int = 640;

	public var velocityX: Float;
	public var velocityY: Float;

	public var posX: Float;
	public var posY: Float;

	var width: Float;
	var height: Float;

	var spawned: Array<Dynamic>; // :pain:

	public var runFibers = true;

	var activeObjects: Array<Sprite>;
	var activeFibers: Array<CannonBullet>;
	var activeMeshes: Array<h3d.scene.Object>;

	public static var cache = new h3d.prim.ModelCache();
	public var o3d: h3d.scene.Object;
	public var meshZ: Float = -7;

	public var pause = false; // Pause the whole dang level
	var pauseForClear = false; // Just stop scrolling until we clear the screen


	public var fogColor(get,never): Int;
	public function get_fogColor(){ return levelData.fogColor; }



	public function new( data: CBLFile, width: Float, height: Float, ?parent: Object )
	{
		super(parent);
		levelData = data;
		activeObjects = [];
		activeFibers = [];
		spawned = [];
		activeMeshes = [];
		this.width = width;
		this.height = height;

		o3d = new h3d.scene.Object();

		if( data == null ) return;

		//posY = data.height;

		velocityX = data.velocity.x;
		velocityY = data.velocity.y;



		//haxe.ds.ListSort.sortSingleLinked(objects.head, function(a, b): Int{ return cast a.elt.spawnPosition - b.elt.spawnPosition; });
	}

	override function onRemove()
	{
		super.onRemove();
	}

	public dynamic function onLevelEnd()
	{

	}

	public function tick( delta: Float )
	{
		var oldPX = posX;
		var oldPY = posY;

		if( pause ) return;

		for( o in activeObjects )
		{
			o.tick(delta);
		}

		var i =activeFibers.length;
		while( i-- > 0 )
		{
			var f = activeFibers[i];
			if( !f.isActive || f.destructionStatus != -1 )
				activeFibers.splice(i,1);
		}

		if( pauseForClear )
		{
			if( activeFibers.length > 0 )
				return;

			pauseForClear = false;

		}



		posX += delta * velocityX;
		posY += delta * velocityY;

		// backsolve 3d offset
		var p = o3d.getScene().camera.unproject( oldPX, oldPY, meshZ );
		var p2 = o3d.getScene().camera.unproject( posX, posY, meshZ );

		o3d.x += p2.x - p.x;
		o3d.y += p2.y - p.y;

		// ??
		//o3d.x = posX;
		//o3d.y = posY;

		updateSpawns();



		//spawnPosition = pos;
	}

	function rebuild()
	{
		for( a in activeObjects )
		{
			a.remove();
		}
		for( a in activeMeshes )
		{
			a.remove();
		}
		spawned = [];
		activeObjects = [];
		activeMeshes = [];
		pauseForClear = false;
		pause = false;

		updateSpawns();

	}



	function updateSpawns()
	{
		// @todo HOLY HELL THIS IS BAD
		// At a minimum we should sort these and only check head/pop.

		var aabbCollider = new AABB({ min: {x: 0, y: 0}, max: { x: viewportWidth, y: viewportHeight } });
		for( o in levelData.sprites)
		{
			// Hack: If runfibers is 0 we always spawn because that means we're in the level editor
			// look it's LD don't think about it too hard
			if( ( o.spawnGroup == 0 || !runFibers) && spawned.indexOf( o ) == -1 && aabbCollider.intersectsPoint( posX, posY, o.position.x, o.position.y ) )
			{
				spawnObject(o);
				spawned.push(o);
			}
		}

		for( o in levelData.spawnGroups)
		{

			if( spawned.indexOf( o ) == -1 && aabbCollider.intersectsPoint( posX, posY, o.position.x, o.position.y ) )
			{
				for( s in levelData.sprites)
				{
					if( s.spawnGroup == o.id )
						spawnObject(s);
				}
				spawned.push(o);
			}
		}

		for( o in levelData.triggers)
		{

			if( runFibers && spawned.indexOf( o ) == -1 && aabbCollider.intersectsPoint( posX, posY, o.position.x, o.position.y ) )
			{
				spawned.push( o );
				executeTrigger( o );
			}
		}

		for( o in levelData.meshes)
		{
			if( spawned.indexOf( o ) == -1  && aabbCollider.intersectsPoint( posX, posY, o.position.x, o.position.y  ) )
			{
				spawned.push( o );
				spawnMesh(o);
			}
		}

	}

	function spawnMesh( o :CBLMesh)
	{
		var upx = o.position.x - viewportWidth / 2; // Correct for projection inconsistency wrt negative coords
		var upy = o.position.y;
		var p = o3d.getScene().camera.unproject( upx, upy, meshZ ); // 2d space -> 3d space
		var newObject = cache.loadModel( hxd.Res.loader.load( o.mesh ).toModel() );
		var sx = p.x; // * viewportWidth / 640.; // Correct for condensed viewport
		var sy = p.y;

		newObject.x = sx;
		newObject.y = -sy;
		newObject.z = meshZ;
		newObject.rotate(0,0,o.rotation);
		if( o.scale > 0 )
			newObject.scale(o.scale);
		//newObject.scale(0.17);


		activeMeshes.push( newObject );
		o3d.addChild(newObject);
	}

	function executeTrigger(t: CBLTrigger)
	{
		switch(t.type)
		{
			case ChangeVelocity:
				velocityX = t.data.x;
				velocityY = t.data.y;
			case PauseForClear:
				pauseForClear = true;
			case Dialogue:
				#if butai
				GameState.butai.jump('dialogue_${Math.floor( t.data.x )}' );
				#end
			case LevelEnd:
				onLevelEnd();
			case None:

		}
	}


	public function simluateMove( newX: Float, newY: Float )
	{
		var offsetX = posX - newX;
		var offsetY = posY - newY;
		for(o in activeObjects )
		{
			o.x += offsetX;
			o.y += offsetY;
		}

		// backsolve 3d offset
		var p = o3d.getScene().camera.unproject( posX, posY, meshZ );
		var p2 = o3d.getScene().camera.unproject( newX, newY, meshZ );

		o3d.x += p2.x - p.x;
		o3d.y += p2.y - p.y;

		posX = newX;
		posY = newY;

		if( runFibers )
		{
			BulletManager.destroy();
			rebuild();
		}
		else
			updateSpawns();
	}

	function spawnObject(o: CBLObject)
	{
		var s: Sprite;
		var sx = o.position.x - posX;
		var sy = o.position.y - posY;
/*
		if( velocityX > 0 )
			sx -= bounds.width;
		else if( velocityX < 0 )
			sx += bounds.width;
		else
			sx -= bounds.width / 2;

		if( velocityY > 0 )
			sy -= bounds.height;
		else if( velocityY < 0 )
			sy += bounds.height;
		else
			sy -= bounds.height / 2;
*/
		if( runFibers && o.fiber != null  )
		{
			var b = BulletManager.createCustomSeed( compileFiber(o), sx, sy, o.rotation );
			activeFibers.push(cast b.object);
			var bullet: CannonBullet = cast b.object;
			bullet.useOffset = true;
			bullet.fiber = b; // I shouldn't need to do this.


		}
		else
		{
			s = hxd.Res.loader.loadCache( o.sprite, cerastes.fmt.SpriteResource ).toSprite(this);
			var b = s.getBounds();
			s.x = sx;// - b.width / 2;
			s.y = sy;// - b.height / 2;
			activeObjects.push(s);
		}




	}

	function compileFiber(o: CBLObject)
	{
		var str = '&spr\'${o.sprite}\'
${o.fiber}';
		str = StringTools.replace( str, "<speed.x>", ""+o.speed.x );
		str = StringTools.replace( str, "<speed.y>", ""+o.speed.y );

		str = StringTools.replace( str, "<accel.x>", ""+o.acceleration.x );
		str = StringTools.replace( str, "<accel.y>", ""+o.acceleration.y );

		return str;
	}
}

#end