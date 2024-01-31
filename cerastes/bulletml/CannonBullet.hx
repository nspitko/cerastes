package cerastes.bulletml;
#if cannonml
import cerastes.collision.Colliders.Circle;
import cerastes.collision.Collision.CAABB;
import cerastes.collision.Collision.CollisionMask;
import cerastes.collision.Colliders.Collider;
import cerastes.collision.Collision.CCircle;
import cerastes.collision.Colliders.CollisionObject;
import cerastes.fmt.SpriteResource;

import hxd.res.Loader;
import h2d.Tile;
import h2d.Graphics;
import h2d.col.Point;
import cerastes.CollisionManager;
import h2d.Bitmap;
import h2d.col.Bounds;
import h2d.Object;
import cerastes.Utils.*;
import org.si.cml.*;
import org.si.cml.CMLObject;
import cerastes.CollisionManager.Collidable;

enum abstract CannonDestructonReason(Int) from Int to Int {
    var ALIVE = -1;             // Bullet is alive

    var NONE = 0;               // No reason specified. This shouldn't be set (but probably will be; treat like FINISHED)
    var FINISHED = 1;           // This bullet has completed its task and should be removed gracefully
    var EXIT_SCENE = 2;         // This vullet has exited the scene and should just be removed
    var COLLISION = 3;          // This bullet hit its target
    var DEATH = 3;              // A sprite attached to me died


    var SCENE_CLEAR = 9;        // Special case: We called DestroyAll(), treat similarly to EXIT_SCENE

}

// An actor attached to a bullet. Mostly used for attaching enemies to bullet patterns
interface BulletActor
{
    public var bullet: CannonBullet;
	public var fiber: CMLFiber;
}

class CannonBullet extends CMLObject implements CollisionObject
{
	// Static junk ( Shared across particle container )
    static public var minX = 0;
    static public var minY = 0;
    static public var maxX = 256;
    static public var maxY = 256;
    static private var _freeList:Array<CannonBullet> = [];

	// Cerastes-specific
	static public var container : Object;

    public var bitmap : Bitmap;
	public var sprite : Sprite;
	public var position = new Point(0,0);
	public var active = false; // Is collision active?

    public var fiber: CMLFiber; // Surely I can get to this without the backsolve????

    // Collidable
    public var collider : Collider;

    // CollisionObject
    public var collisionMask: CollisionMask;	// Things that can interact with me
	public var collisionType: CollisionGroup;	// My interaction type
    public var colliders(default, null): haxe.ds.Vector<Collider>;

    public var damage: Float = 10;

    public var debug : Graphics;

    public var padding = 6;

    var offsetX: Float = 0;
    var offsetY: Float = 0;

    public var useOffset = false;



    static private function _new() : CannonBullet
    {
        if( _freeList.length > 0 )
        {
            return _freeList.pop();
        }

        return new CannonBullet( container );
    }

    public static dynamic function updateCollider( b: CannonBullet, width: Float, height: Float )
    {
        if( false && b.sprite != null )
        {
            b.collider = b.sprite.colliders[0].clone(b.offsetX, b.offsetY);
            b.colliders[0] = b.collider;
        }
        else if( b.collider != null)
        {
            var c: Circle = cast b.collider;
            c.r = Math.min( width/2, height/2 );
        }
        else
        {
            b.collider = new Circle({p: {x: 0, y: 0}, r: Math.min( width/2, height/2 ) });
            b.colliders = new haxe.ds.Vector4(1);
            b.colliders[0] =  b.collider;
        }
    }

    public function handleCollision( other: CollisionObject )
    {
        sprite.remove();
        destroy(COLLISION);
    }

    public function setCollision( type: CollisionGroup, mask: CollisionMask, damage: Float )
    {
        if( collider == null )
        {
            updateCollider(this,5,5);
        }
        collisionType = type;
        collisionMask = mask;
        this.damage = damage;
        GameState.collisionManager.insert(this);

    }

    // @todo?
	//public var collisionBounds : CAABB;

	public function new( parent: Object )
    {

        container = parent;
        colliders = new haxe.ds.Vector4(1);

        updateCollider(this, 5, 5);

        //bitmap = new Bitmap(Tile.fromColor(0xffffffff,8,8), bitmapContainer);

        //setTile( hxd.Res.spr.atlas.getAnim("spr_bullet")[2 ] );
        //setTile( Tile.fromColor(0xffffff,12,12) );


        active=true;


        //CollisionManager.instance.register(this);
        //trace("Construct");
        super();
	}

    public function setTile( tile: Tile )
    {
        if( sprite != null ) sprite.remove();

        if( bitmap != null  )
        {
            container.addChild(bitmap);
            if( bitmap.tile == tile)
                return;

            bitmap.tile = tile;
        }
        else
        {
            bitmap = new Bitmap(tile, container);
        }


        updateCollider(this, tile.width - padding * 2, tile.height - padding * 2);

        bitmap.tile.dx = -tile.width/2 - padding/2;
        bitmap.tile.dy = -tile.height/2 - padding/2;
    }

    public function setSprite( name: String )
    {
        if( bitmap != null  )
        {
            bitmap.remove();
        }

        if( sprite != null  )
        {
            sprite.currentFrame = 0;
            container.addChild(sprite);
            if( sprite.spriteDef.name == name)
                return;

            sprite.remove();
        }

        sprite = hxd.Res.loader.loadCache( name, SpriteResource ).toSprite( container );

        if( sprite == null )
            return;

        var enemy: BulletActor = cast Std.downcast( sprite, cast BulletActor );
        if( enemy != null )
        {
            enemy.bullet = this;
            enemy.fiber = fiber;
        }


        updateBounds();
    }

    function updateBounds()
    {
        var obj = getActiveObject();
        if( obj != null )
        {
            var bounds = obj.getBounds();
            //offsetX = -sprite.originX;
            //offsetY = -sprite.originY;
            updateCollider( this, bounds.width, bounds.height );

        }

    }

    public function setScale( scale: Float )
    {
        Utils.error("STUB");
        //bitmapContainer.setScale(scale);
        updateBounds();
    }

    override public function _initialize(parent_:CMLObject, isPart_:Bool, access_id_:Int, x_:Float, y_:Float, vx_:Float, vy_:Float, head_:Float) : CMLObject
    {
        var b = Std.downcast(parent_,CannonBullet );

        if( b != null  )
        {
            setCollision( b.collisionType, b.collisionMask, b.damage);

        }

        return super._initialize(parent_, isPart_, access_id_, x_, y_, vx_, vy_, head_);
    }

    override public function onNewObject(args:Array<Dynamic>) : CMLObject {
        var ret = _new();
        ret.active = true;
        ret.useOffset = false;
        return ret;
    }
    override public function onFireObject(args:Array<Dynamic>) : CMLObject {
        var ret = _new();
        ret.active = true;
        ret.useOffset = false;


        return ret;
	}
    override public function onDestroy()
    {


        var obj = getActiveObject();
        if( obj != null )
        {
            obj.remove();
        }

        GameState.collisionManager.remove(this);


        //if( bitmap != null )
        //    bitmap.visible = false;

        active=false;
        _freeList.push(this);

    }

    function getActiveObject() : Object
    {
        if( sprite != null && sprite.parent != null ) return sprite;
        if( bitmap != null && bitmap.parent != null ) return bitmap;

        return null;
    }


    override public function onUpdate()  {
        position.x = x;
        position.y = y;

        var obj = getActiveObject();
        if( obj != null )
        {
            if( false && useOffset )
            {
                obj.x = x + offsetX;
                obj.y = y + offsetY;
            }
            else
            {
                obj.x = x;
                obj.y = y;
            }

            obj.rotation = (90 + this.angle) * (Math.PI/180);
        }
        //if( !this.isActive )
        active = this.isActive;

        if( sprite != null && sprite.parent != null )
            sprite.tick( 1/60 );




        if (this.x<minX || this.x>maxX|| this.y<minY || this.y>maxY) this.destroy(2);


    }
}

#end