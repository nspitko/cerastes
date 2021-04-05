package cerastes.bulletml;
#if bulletml
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
    public var bitmapContainer: Object;
	public var position = new Point(0,0);
	public var active = true; // Is collision active?

    public var debug : Graphics;

    public var padding = 6;
    
	

    static private function _new() : CannonBullet 
    {
        if( _freeList.length > 0 )
            return _freeList.pop(); 
        
        
        return new CannonBullet( container ); 
    }

	public function new( parent: Object ) 
    {
        
        container = parent;
        

        //bitmap = new Bitmap(null, bitmapContainer);

        setTile( hxd.Res.spr.atlas.getAnim("spr_bullet")[2 ] );

        bitmapContainer = new Object(parent);
        

        debug = new Graphics(parent);
        
        active=true;

        CollisionManager.instance.register(this);
        //trace("Construct");
        super();
	}

    public function setTile( tile: Tile )
    {
        if( bitmap != null )
            bitmap.remove();
            
        bitmap = new Bitmap(tile, bitmapContainer);
        bitmap.getSize(aabb);
        bitmap.visible = true;


        aabb.width -= padding;
        aabb.height -= padding;
        bitmap.x = -aabb.width/2 - padding/2;
        bitmap.y = -aabb.height/2 - padding/2;
    }

    public function setScale( scale: Float )
    {
        assert( bitmap != null, "Trying to set scale on null bitmap???");
            
        bitmap.setScale( scale );
    }


    override public function onNewObject(args:Array<Dynamic>) : CMLObject { 
        var ret = _new();
        ret.active = true;
        return ret;
    }
    override public function onFireObject(args:Array<Dynamic>) : CMLObject { 
        var ret = _new();
        if( args.length == 1 )
        {
            ret.setTile( hxd.Res.spr.atlas.getAnim("spr_bullet")[cast args[0] - 1 ]);
            //trace('spr_bullet_'+ Std.string( args[0] ));
            return ret;
        }
        ret.active = true;
		return _new(); 
	}
    override public function onDestroy() 
    { 
        //bitmap.remove(); 
        if( debug != null && SHOW_BULLET_AABBS )
            debug.clear();

        bitmap.visible = false;

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

        
        debug.clear();

        if( active && SHOW_BULLET_AABBS )
        {
            debug.lineStyle(1,0xCC0000);

            debug.moveTo( position.x, position.y);
            debug.lineTo( position.x + aabb.width, position.y );
            debug.lineTo( position.x + aabb.width, position.y + aabb.height );
            debug.lineTo( position.x, position.y + aabb.height );
            debug.lineTo( position.x, position.y );
        }
            
        bitmapContainer.rotation = (90 + this.angle) * (Math.PI/180);
        //if (this.x<minX || this.x>maxX|| this.y<minY || this.y>maxY) this.destroy(0);

        
    }
}

#end