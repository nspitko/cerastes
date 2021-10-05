package cerastes;

import cerastes.butai.ButaiNodeManager;
import game.GameState;
import cerastes.InputManager.InputListener;
import cerastes.InputManager.InputButton;
import cerastes.InputManager.InputState;
import game.scenes.GameScene;
import game.PSXMaterialSetup;
#if !workaround
import game.objects.PlayerSprite;
#end
import game.objects.Enemy;
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

	var pauseForClear = false;
	var pauseForDead = false;

	var lines: Array<String>;

	var inputListener: InputListener;


#if !workaround
	public var player: PlayerSprite;
#end

	var dialogueNode: DialogueNode;

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
		#if !workaround
		player = cast hxd.Res.spr.player_csd.toSprite(this);

		player.x = 360 / 2;
		player.y = 480 * 0.8;

		#end

		GameState.immortal = false;

		PSXMaterial.fogColor = levelData.fogColor;

		inputListener =  {callback: this.onInput, priority: 150 };


		GameState.butai.registerOnDialogueNode(this, onDialogue);

		//haxe.ds.ListSort.sortSingleLinked(objects.head, function(a, b): Int{ return cast a.elt.spawnPosition - b.elt.spawnPosition; });
	}

	override function onRemove()
	{
		GameState.butai.unregisterOnDialogueNode(this);
		super.onRemove();
	}

	function levelEnd()
	{
		var l = GameState.level;
		GameState.level++;
		GameState.butai.unregisterOnDialogueNode(this);
		GameState.butai.jump('LevelEnd${l}');
	}

	public function tick( delta: Float )
	{
		var oldPX = posX;
		var oldPY = posY;

		if( GameState.goFast ) delta *= 100;

		if( GameState.inDialogue ) return;
		if( pauseForDead ) return;

		if( player.health <= 0 )
		{
			pauseForDead = true;

			var ded = hxd.Res.ui.gameover.toObject();
			Main.currentScene.s2d.addChild( ded );

			// ???????
			GameState.butai.unregisterOnDialogueNode(this);

			new Timer(5, function(){
				GameState.butai.jump("Title");
			});
		}

		#if !workaround
		player.tick(delta);
		#end

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
		GameState.inDialogue = false;

		updateSpawns();

	}

	private function onInput( button: InputButton, state: InputState, delta: Float  )
	{

		if( state == InputState.PRESSED && button == InputButton.START )
			nextLine();

		return true;
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


		//trace('${sx}x${sy}x${meshZ}');

		for(m in newObject.getMaterials() )
		{
			if(m.texture == null )
				m.texture = hxd.Res.mdl.bldg4.toTexture();
		}

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
				GameState.butai.jump('dialogue_${Math.floor( t.data.x )}' );
			case LevelEnd:
				levelEnd();
			case None:

		}
	}

	function onDialogue( node: DialogueNode, handled: Bool )
	{
		dialogueNode = node;
		if( node == null ) return false;

		InputManager.register( inputListener );

		lines = node.dialogue.split("\n");
		GameState.inDialogue = true;

		nextLine();

		return true;
	}

	function nextLine()
	{
		var line = lines.shift();
		var gs: GameScene = Std.downcast( Main.currentScene, GameScene );
		if( gs == null ) return;

		if( line == null )
		{
			InputManager.unregister( inputListener );
			GameState.inDialogue = false;
			gs.dialogue.visible = false;
			GameState.butai.nextAll(dialogueNode);
			return;
		}

		var r = ~/&[A-z\-]+/g;
		if( r.match(line ) )
		{
			var exp = StringTools.trim( r.matched(0) ).substr(1);

			gs.setExpression(exp);

			line = StringTools.trim( r.replace( line, "" ) );


		}

		line = StringTools.trim( StringTools.replace(line, "<br>","\n") );
		line = StringTools.replace(line, "\r\n","\n");
		line = StringTools.replace(line, "\n\n","\n");
		line = StringTools.replace(line, "  "," ");



		gs.dialogue.visible = true;

		var fuck = ~/[：:]/g;
		var bits = fuck.split(line);

		if( bits.length > 1 )
		{
			var speaker = bits.shift();
			gs.setSpeakerName(speaker);

		}
		else
		{
			gs.setSpeakerName(null);
		}

		var line = bits.join(":");

		gs.setDialogueText(line);

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