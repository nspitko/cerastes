
package cerastes.c3d;

import bullet.Native;
import bullet.Shape;
import h3d.Matrix;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import cerastes.c3d.Prefab.PrefabDef;
import h3d.Vector;
import h3d.Quat;
import h3d.scene.World;
import h3d.scene.Object;

@:structInit
class PrefabEntry
{
	public var file: String;
	public var x: Float;
	public var y: Float;
	public var z: Float;
	public var rotation: Quat;
}

@:structInit
class GeoEntry
{
	public var file: String;
	public var transform: Matrix;
}

@:structInit
class WorldDef
{
	public var prefabs: Array<PrefabEntry>;
	public var geo: Array<GeoEntry>;

	public function save(file: String)
	{
		var kv = CDPrinter.print(this);
		sys.io.File.saveContent( Utils.fixWritePath(file,"world"),kv);
	}

	public static function load( file: String )
	{
		return CDParser.parse( hxd.Res.load( file ).toText(), WorldDef );
	}
}

// The megaclass.
class World extends Object
{
	public var physics: bullet.World;
	public var geo: h3d.scene.World;

	var geoPhysics: Map<Int, Shape> = [];

	public static var physicsMaxSubSteps = 1;

	var entities: Array<Entity> = [];

	public function new( ?parent: Object )
	{
		super( parent );
		physics = new bullet.World(this);
		physics.setGravity(0,0,-9.8);
		geo = new h3d.scene.World(64, this);
	}

	public function load( def: WorldDef )
	{
		if( def.prefabs != null )
		{
			for( entry in def.prefabs )
			{
				var def = PrefabDef.load( entry.file );
				var prefab = new Prefab(this);
				prefab.load(def);
				prefab.setPosition ( entry.x, entry.y, entry.z );
				prefab.setRotationQuat( entry.rotation.clone() ); // Clone here to avoid holding on to the whole worlddef
			}
		}

		if( def.geo != null )
		{
			// @todo cache!!
			var modelCache = new Map<String, WorldModel>();
			for( entry in def.geo )
			{
				var worldModel: WorldModel = modelCache.get(entry.file);
				if( worldModel == null )
				{
					var model = hxd.Res.loader.loadCache( entry.file, hxd.res.Model );
					worldModel = geo.loadModel( model );
					modelCache.set(entry.file, worldModel );
				}

				geo.addTransform( worldModel, entry.transform );


			}
		}

	}

	@:access(h3d.scene.World)
	public function generateChunkPhysics()
	{
		/*
		for(idx => chunk in geo.chunks)
		{
			if( chunk.initialized && !geoPhysics.exists(idx) )
			{

				var shapes = new Array<BvhTriangleMeshShape>();


				for( buffer in chunk.buffers )
				{
					var triangleArray = new bullet.Native.TriangleMesh(false,false);
					var prim = buffer.primitive;
					for( bufferIdx in 0 ... prim.indexes.count )
					{
						var vert = prim.buffer.buffer[bufferIdx];
						triangleArray.addTriangle( vert.x, vert.y, vert.z, true );
					}
					var shape = new bullet.Native.BvhTriangleMeshShape(triangleArray, true, true);
				}



				//int.
				//var p = new BvhTriangleMeshShape()
			}



			//var triangleShape = new Native.BvhTriangleMeshShape(  )
		}

			*/
	}

	public function add( e: Entity )
	{
		e.setWorld( this );
		entities.push( e );
	}

	public function tick(delta: Float)
	{
		// Scans world chunks for any we might not have generated geo for yet
		generateChunkPhysics();

		physics.stepSimulation( delta,physicsMaxSubSteps);
		for( e in entities )
			e.tick(delta);
	}


}