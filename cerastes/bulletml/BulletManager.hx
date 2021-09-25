package cerastes.bulletml;

import cerastes.macros.Metrics;
import org.si.cml.core.CMLState;
import cerastes.fmt.SpriteResource;
import h2d.Tile;
import haxe.Json;
#if cannonml

import hxd.res.Loader;
import org.si.cml.CMLFiber;
import org.si.cml.core.CMLParser;
import org.si.cml.core.CMLBarrage;
import h2d.col.Point;
import cerastes.CollisionManager;
import org.si.cml.CMLSequence;
import org.si.cml.CMLObject;
import h2d.Object;


typedef CannonFile = Array<{name: String, fiber: String}>;

/**
 * ??? EEEEEEEEEEE
 */
class BulletManager
{
	//public static var instance(default, null):BulletManager = new BulletManager();

	static var bullets = new Array<CannonBullet>();
	public static var target : Object;
	public static var container : Object;

	static var patternList: Map<String, String>;

	static var seed:CannonBullet;
	static var parent:Object;
	//var seedB:CannonBullet;

	static var cmlTarget : CMLObject;

	private static var cmlRoot : CMLObject;


	/**
	 * Initializes the bullet manager
	 * @param pObject
	 * @param file - Empty string indicates no file to load (used for tools)
	 */
	public static function initialize(pObject: Object, ?file: String = "data/bullets.cml")
	{
		if( cmlRoot == null )
			cmlRoot = CMLObject.initialize(true);

		CannonBullet.maxX = 640;
		CannonBullet.maxY = 480;

		//seedB = new CannonBullet(this,collisionManager);
		//seedB.create(10, 0);

		cmlTarget = new CMLObject();
		cmlTarget.setAsDefaultTarget();

		var t = Tile.fromColor(0xFFFFFF,12,12);

		CMLParser.userCommand("tex",
			function(fiber: CMLFiber, args: Array<Dynamic>){
				var o : CannonBullet = cast fiber.object;
				//o.setTile(hxd.Res.spr.atlas.getAnim("spr_bullet")[cast args[0] - 1 ] );
				o.setTile( t );

			},
			1,
			false
		);
		CMLParser.userCommand("spr",
			function(fiber: CMLFiber, args: Array<Dynamic>){
				var o : CannonBullet = cast fiber.object;
				o.setSprite( "" + args[0] );
			},
			1,
			false
		);
		CMLParser.userCommand("sca",
			function(fiber: CMLFiber, args: Array<Dynamic>) {
				var o : CannonBullet = cast fiber.object;
				o.setScale(cast args[0] );
			},
			1,
			false
		);

		if( patternList == null && file != "" )
			loadFromDisk( file );


		parent = pObject;

		CMLObject.destroyAll(9);

		seed = new CannonBullet(parent);
		seed.create(0, 0);
		seed.active = false;
	}

	static function loadFromDisk(file: String)
	{
		patternList = [];

		var data : CannonFile = Json.parse( hxd.Res.load( file ).entry.getText() );
		for( child in data )
			patternList.set( child.name, child.fiber );
	}

	public static function createSeed( pattern: String, x: Float, y: Float )
	{
		var seq = new CMLSequence( patternList.get(pattern) );
		var obj = seed.execute( seq );

		obj.fx = x;
		obj.fy = y;

		return obj;
	}

	public static function destroy()
	{
		CMLObject.destroyAll(9);
		seed = new CannonBullet(parent);
		seed.create(0, 0);
		seed.active = false;
		//cmlRoot = null;

	}

	public static function tick( delta:Float )
    {
		Metrics.begin();
		if( target != null )
		{
			cmlTarget.x = target.x;
			cmlTarget.y = target.y;
		}

		CMLObject.frameUpdate();
		Metrics.end();
    }
}

#end