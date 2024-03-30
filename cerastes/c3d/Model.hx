package cerastes.c3d;

import hxd.fmt.hmd.Data.Material;
import h3d.prim.HMDModel;
import h3d.prim.ModelCache;
import hxd.fmt.hmd.Library;
import cerastes.c3d.Material.MaterialDef;
import hxd.res.Model;
import h3d.scene.Mesh;
import h3d.scene.Object;

@:structInit
class ModelPoint
{
	public var x: Float = 0;
	public var y: Float = 0;
	public var z: Float = 0;
}

@:structInit
class Attachment
{
	public var joint: String;
	public var offset: ModelPoint;

}


@:structInit
class JointMask
{
	public var joints: Array<String>;
	public function toMap() : Map<String, Bool>
	{
		var out = new Map<String, Bool>();
		for( j in joints )
			out.set(j, true);

		return out;
	}
}

@:structInit
class ModelDef
{
	public var file: String;

	@serializeType("haxe.ds.StringMap")
	public var materialMap: Map<String,String> = [];

	@serializeType("cerastes.c3d.JointMask")
	public var jointMasks: Map<String, JointMask> = [];

	// String separated list of additional libraries to load (for animations)
	public var libraries: Array<String> = [];

	@noSerialize
	static var cache: Map<String, Library> = [];

	public var scale: Float = 1;
	@serializeType("cerastes.c3d.ModelPoint")
	public var rotation: ModelPoint = {};

	public function getAnimations() : Array< h3d.anim.Animation >
	{
		var anims: Array< h3d.anim.Animation > = [];
		var lib = getLibrary(file);

		for( a in lib.header.animations )
		{
			anims.push(lib.loadAnimation(a.name));
		}

		for( l in libraries )
		{
			var lib = getLibrary(l);
			for( a in lib.header.animations )
			{
				anims.push(lib.loadAnimation(a.name));
			}
		}

		return anims;
	}

	function getLibrary( file: String )
	{
		var library: Library = cache.get(file);

		if( !cache.exists( file ))
		{
			var model = hxd.Res.loader.loadCache( file, Model );
			library = model.toHmd();

			cache.set(file, library);
		}

		return library;
	}

	public function toObject( ?parent: Object = null ): h3d.scene.Object
	{
		if( file == null || file == "")
			return new Object();

		// fixup
		if( materialMap == null )
			materialMap = [];


		var library = getLibrary(file);

		//var obj  = new h3d.scene.Object( parent );

		var objs = [];
		for( m in library.header.models )
		{
			var obj : h3d.scene.Object = null;
			if( m.geometry < 0 )
			{
				obj = new h3d.scene.Object( );
			}
			else
			{
				var prim = @:privateAccess library.makePrimitive(m);

				if( m.skin != null )
				{
					var skinData = @:privateAccess library.makeSkin(m.skin, library.header.geometries[m.geometry]);
					skinData.primitive = prim;
					obj = new h3d.scene.Skin(skinData, [for( idx in m.materials ) loadMaterial(materialMap, library.header.materials[idx] ) ]);
				} else if( false && m.materials.length == 1 )
					obj = new h3d.scene.Mesh(prim, loadMaterial(materialMap, library.header.materials[0] ), obj );
				else
					obj = new h3d.scene.MultiMaterial(prim, [for( idx in m.materials ) loadMaterial(materialMap, library.header.materials[idx] )], obj);

				//var prim: HMDModel =cast  @:privateAccess cast (obj, h3d.scene.Mesh).primitive;
			}

			obj.name = m.name;
			obj.defaultTransform = m.position.toMatrix();
			#if orientationhack
			//obj.rotate(Math.PI/2,0,-Math.PI);
			#end

			var r = Math.PI / 180;

			if( rotation != null )
				obj.rotate( rotation.x * r, rotation.y * r, rotation.z * r );

			// Test for 0 for back compat. Can be removed later.
			if( scale > 0 && scale != 1 )
				obj.scale( scale );

			objs.push( obj );
		}

		for( i in 0 ...library.header.models.length )
		{
			var m = library.header.models[i];
			if( m.parent >= 0 && i != m.parent )
				objs[m.parent].addChild(objs[i]);
		}


		var o = objs[0];
		if( o != null )
			o.modelRoot = true;

		if( parent != null )
			parent.addChild(o);



		return o;

	}

	function loadMaterial( materialMap: Map<String, String>, material: Material )
	{
		var file = materialMap[material.name];
		return MaterialDef.loadMaterial( file );
	}

}