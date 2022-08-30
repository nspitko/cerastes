package cerastes.c3d;

import h3d.prim.ModelCache;
import hxd.fmt.hmd.Library;
import cerastes.c3d.Material.MaterialDef;
import hxd.res.Model;
import h3d.scene.Mesh;
import h3d.scene.Object;

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
	// String separated list of materials to apply, in slot order
	public var materials: Array<String> = [];

	@serializeType("cerastes.c3d.JointMask")
	public var jointMasks: Map<String, JointMask> = [];

	// String separated list of additional libraries to load (for animations)
	public var libraries: Array<String> = [];

	@noSerialize
	static var cache: Map<String, Library> = [];

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
				var prim = @:privateAccess library.makePrimitive(m.geometry);

				if( m.skin != null )
				{
					var skinData = @:privateAccess library.makeSkin(m.skin, library.header.geometries[m.geometry]);
					skinData.primitive = prim;
					obj = new h3d.scene.Skin(skinData, [for( idx in 0 ... m.materials.length ) loadMaterial(materials[idx])]);
				} else if( m.materials.length == 1 )
					obj = new h3d.scene.Mesh(prim, loadMaterial( materials[0] ), obj );
				else
					obj = new h3d.scene.MultiMaterial(prim, [for( idx in 0 ... m.materials.length ) loadMaterial(materials[idx])], obj);
			}

			obj.name = m.name;
			obj.defaultTransform = m.position.toMatrix();
			#if orientationhack
			//obj.rotate(Math.PI/2,0,-Math.PI);
			#end

			objs.push(obj);
			var p = objs[m.parent];
			if( p != null )
				p.addChild(obj);


		}


		var o = objs[0];
		if( o != null )
			o.modelRoot = true;

		if( parent != null )
			parent.addChild(o);

		return o;

	}

	function loadMaterial( file: String )
	{
		return MaterialDef.loadMaterial( file );
	}

}