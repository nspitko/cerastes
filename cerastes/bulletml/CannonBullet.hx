package cerastes.bulletml;
import cerastes.fmt.SpriteResource;
#if cannonml
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

@:enum
abstract CannonDestructonReason(Int) from Int to Int {
    var ALIVE = -1;             // Bullet is alive

    var NONE = 0;               // No reason specified. This shouldn't be set (but probably will be; treat like FINISHED)
    var FINISHED = 1;           // This bullet has completed its task and should be removed gracefully
    var EXIT_SCENE = 2;         // This vullet has exited the scene and should just be removed
    var COLLISION = 3;          // This bullet hit its target


    var SCENE_CLEAR = 9;        // Special case: We called DestroyAll(), treat similarly to EXIT_SCENE

}

class CannonBullet extends CMLObject implements Collidable
{
	// Static junk ( Shared across particle container )
    static public var minX = 0;
    static public var minY = 0;
    static public var maxX = 256;
    static public var maxY = 256;
    static private var _freeList:Array<CannonBullet> = [];

	// Cerastes-specific
	static public var container : Object;

    // Collidable
    public var aabb : Bounds = new Bounds();
	public var bitmap : Bitmap;
	public var sprite : Sprite;
    public var bitmapContainer: Object;
	public var position = new Point(0,0);
	public var active = false; // Is collision active?

    public var debug : Graphics;

    public var padding = 6;

    static private function _new() : CannonBullet
    {
        if( _freeList.length > 0 )
        {
            return _freeList.pop();
        }

        return new CannonBullet( container );
    }

	public function new( parent: Object )
    {

        container = parent;
        bitmapContainer = new Object(parent);

        //bitmap = new Bitmap(Tile.fromColor(0xffffffff,8,8), bitmapContainer);

        //setTile( hxd.Res.spr.atlas.getAnim("spr_bullet")[2 ] );
        //setTile( Tile.fromColor(0xffffff,12,12) );



        if( SHOW_BULLET_AABBS )
            debug = new Graphics(parent);

        active=true;


        //CollisionManager.instance.register(this);
        //trace("Construct");
        super();
	}

    public function setTile( tile: Tile )
    {
        if( sprite != null )
        {
            sprite.visible = false;
        }

        bitmapContainer.visible = true;
        bitmapContainer.setScale(1);
        if( bitmap != null  )
        {
            bitmap.visible = true;
            if( bitmap.tile == tile)
                return;

            bitmap.tile = tile;
        }
        else
        {
            bitmap = new Bitmap(tile, bitmapContainer);
        }

        bitmap.getSize(aabb);

        aabb.width -= padding;
        aabb.height -= padding;
        bitmap.x = -aabb.width/2 - padding/2;
        bitmap.y = -aabb.height/2 - padding/2;
    }

    public function setSprite( name: String )
    {
        bitmapContainer.visible = true;
        bitmapContainer.setScale(1);
        if( bitmap != null  )
        {
            bitmap.visible = false;
        }

        if( sprite != null  )
        {
            sprite.currentFrame = 0;
            sprite.visible = true;
            if( sprite.spriteDef.name == name)
                return;

            sprite.remove();
        }

        sprite = BulletManager.spritePack.getSprite( name, bitmapContainer );

        if( sprite == null )
            return;


        sprite.getSize(aabb);

        updateBounds();
    }

    function updateBounds()
    {
        var aabb: Bounds;
        if( sprite.visible )
        {

            aabb = sprite.getBounds();
            aabb.width -= padding;
            aabb.height -= padding;

        }
        else if( bitmap.visible )
        {
            aabb = Bounds.fromValues(0,0,bitmap.width,bitmap.height);
            aabb.width -= padding;
            aabb.height -= padding;

            // @todo fix padding.
            //bitmap.x = -aabb.width/2 - padding/2;
            //bitmap.y = -aabb.height/2 - padding/2;
        }



    }

    public function setScale( scale: Float )
    {
        bitmapContainer.setScale(scale);
        updateBounds();
    }


    override public function onNewObject(args:Array<Dynamic>) : CMLObject {
        var ret = _new();
        ret.active = true;

        if( ret.bitmapContainer.parent != null )
            ret.bitmapContainer.parent.addChildAt(ret.bitmapContainer,0);

        return ret;
    }
    override public function onFireObject(args:Array<Dynamic>) : CMLObject {
        var ret = _new();
        ret.active = true;

        if( ret.bitmapContainer.parent != null)
            ret.bitmapContainer.parent.addChildAt(ret.bitmapContainer,0);

        return ret;
	}
    override public function onDestroy()
    {
        //bitmap.remove();
        if( debug != null && SHOW_BULLET_AABBS )
            debug.clear();

        bitmapContainer.visible = false;
        //if( bitmap != null )
        //    bitmap.visible = false;

        active=false;
        _freeList.push(this);

    }

    override public function onUpdate()  {
        position.x = x;
        position.y = y;

        bitmapContainer.x = x +aabb.width/2 ;
        bitmapContainer.y = y +aabb.height/2 ;
        //if( !this.isActive )
        active = this.isActive;


        if( SHOW_BULLET_AABBS )
        {
            debug.clear();

            if( active )
            {
                debug.lineStyle(1,0xCC0000);

                debug.moveTo( position.x, position.y);
                debug.lineTo( position.x + aabb.width, position.y );
                debug.lineTo( position.x + aabb.width, position.y + aabb.height );
                debug.lineTo( position.x, position.y + aabb.height );
                debug.lineTo( position.x, position.y );
            }
        }
        bitmapContainer.rotation = (90 + this.angle) * (Math.PI/180);
        if (this.x<minX || this.x>maxX|| this.y<minY || this.y>maxY) this.destroy(2);


    }
}

#end