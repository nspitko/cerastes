package cerastes.bulletml;

#if bulletml

import hxd.res.Loader;
import org.si.cml.CMLFiber;
import org.si.cml.core.CMLParser;
import org.si.cml.core.CMLBarrage;
import h2d.col.Point;
import cerastes.CollisionManager;
import org.si.cml.CMLSequence;
import org.si.cml.CMLObject;
import h2d.Object;

// @todo: refactor this to cerastes??
import game.combat.Bullet;
import game.combat.PlayerBullet;


/**
 * ??? EEEEEEEEEEE
 */
class BulletManager
{
	public static var instance(default, null):BulletManager = new BulletManager();

	var bullets = new Array<CannonBullet>();
	public var player : PlayerBullet;
	public var container : Object;

	var patternList = new Map<String, String>();

	var seed:CannonBullet;
	var parent:Object;
	//var seedB:CannonBullet;

	var cmlTarget : CMLObject;

	public var nonPlayerTarget : Bullet;

	private static var cmlRoot : CMLObject;


	public function new()
	{
		if( cmlRoot == null )
			cmlRoot = CMLObject.initialize(true);
	
		

		CannonBullet.maxX = 640;
		CannonBullet.maxY = 480;

		//seedB = new CannonBullet(this,collisionManager);
		//seedB.create(10, 0);
		
		cmlTarget = new CMLObject();
		cmlTarget.setAsDefaultTarget();

		CMLParser.userCommand("tex",
			function(fiber: CMLFiber, args: Array<Dynamic>){
				var o : CannonBullet = cast fiber.get_object();
				o.setTile(hxd.Res.spr.atlas.getAnim("spr_bullet")[cast args[0] - 1 ] );
				
			},
			1,
			false
		);
		CMLParser.userCommand("sca",
			function(fiber: CMLFiber, args: Array<Dynamic>) {
				var o : CannonBullet = cast fiber.get_object();
				o.setScale(cast args[0] );				
			},
			1,
			false
		);


		//patternList 
		
		//seed.execute(new CMLSequence("bs,4,,10bm5,360f10{i30vw90br5,360,2,2f4{i30v~ko}w10ay0.05}"));
		//seed.execute(new CMLSequence("q45,30 nc{ho[w10f2]}i60[p-45,30~ho180r~p45,30~ho180r~p~]"));
		//CannonBullet.container.x = CannonBullet.container.y = 128;

		

	}

	public function initialize(parent: Object)
	{
		var xml = haxe.xml.Parser.parse( hxd.Res.bml.patterns.entry.getText() );
		for( child in xml.firstChild().elements() )
			patternList.set( child.get("name"), child.firstChild().nodeValue );

		this.parent = parent;
		seed = new CannonBullet(parent);
		seed.create(0, 0);
	}

	public function createSeed( pattern: String, x: Float, y: Float )
	{
		var seq = new CMLSequence( patternList.get(pattern) );
		var obj = seed.execute( seq );
			
		obj.fx = x;
		obj.fy = y;

		return obj;
	}

	public function destroy()
	{
		CMLObject.destroyAll(-1);
        CMLFiber._destroyAll();

		
	}

	public function tick( delta:Float )
    {
		CMLObject.frameUpdate();

		if( nonPlayerTarget != null && nonPlayerTarget.active )
		{
			cmlTarget.x = nonPlayerTarget.x;
			cmlTarget.y = nonPlayerTarget.y;
		} else if( player != null ) {
			cmlTarget.x = player.x;
			cmlTarget.y = player.y;
		}

		if( player != null )
		{

			if( CollisionManager.instance.bCollides( player ) )
			{
				player.Hit();
			}
		}
        //combatArea.tick(delta);
    }
}

#end