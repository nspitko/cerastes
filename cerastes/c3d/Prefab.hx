package cerastes.c3d;

import cerastes.file.CDPrinter;
import cerastes.file.CDParser;
import h3d.prim.ModelCache;
import h3d.scene.Object;
import hxd.res.Model;

/**
 * Prefabs describe entities which are ready to be placed in the world.
 */

 enum TextureSlot
 {
	BASE;
	NORMAL;
	ROUGHNESS;
	EXTRA1;
	EXTRA2;
 }

@:enum
abstract BulletShape(Int) from Int to Int
{
	var Box = 0;
	var Sphere = 1;
	var Capsule = 2;

	var Max = 3;
}


@:structInit class ShapeDef
{
	public var shape: BulletShape;
	public var position: h3d.Vector;
	public var x1: h3d.Vector;
	public var x2: h3d.Vector;
	public var x3: h3d.Vector;
	public var x4: h3d.Vector;
}


@:structInit class MaterialDef
{
	public var base: String;
	public var normal: String = null;
	public var roughness: String = null; // r = roughness, g = Metallic, b = AO
	public var extra1: String = null; // Utility slot 1
	public var extra2: String = null; // Utility slot 2
}


@:structInit class ModelDef
{
	public var file: String;
	public var materials: Array<MaterialDef>;
}

@:structInit
class PrefabDef
{
	public var models: Array<ModelDef>;
	public var shapes: Array<ShapeDef>;

	public function save(file: String)
	{
		var kv = CDPrinter.print(this);
		sys.io.File.saveContent( Utils.fixWritePath(file,"prefab"),kv);
	}

	public static function load( file: String )
	{
		return CDParser.parse( hxd.Res.load( file ).toText(), PrefabDef );
	}
}

class Prefab extends h3d.scene.Object
{
	static var cache: h3d.prim.ModelCache = new ModelCache();

	public function load( def: PrefabDef )
	{
		if( def.models != null )
		{
			for( m in def.models )
				addChild( loadModel( m ) );
		}
	}

	@:access(hxd.fmt.hmd.Library)
	function loadModel( def: ModelDef ) : h3d.scene.Object
	{
		var res = hxd.Res.loader.loadCache( def.file, Model );

		var lib = cache.loadLibrary( res );

		if( lib.header.models.length == 0 )
			throw "This file does not contain any model";
		var objs = [];
		for( m in lib.header.models )
		{
			var obj : h3d.scene.Object;
			if( m.geometry < 0 )
			{
				obj = new h3d.scene.Object();
			}
			else
			{
				var prim = lib.makePrimitive(m.geometry);
				if( m.skin != null )
				{
					var skinData = lib.makeSkin(m.skin);
					skinData.primitive = prim;
					obj = new h3d.scene.Skin(skinData, [for( idx in 0 ... m.materials.length ) lib.makeMaterial(m, m.materials[idx], loadTexture.bind( def, BASE, idx ) )]);
				}
				else if( m.materials.length == 1 )
					obj = new h3d.scene.Mesh(prim, lib.makeMaterial(m, m.materials[0],loadTexture.bind( def, BASE, 0 )));
				else
					obj = new h3d.scene.MultiMaterial(prim, [for( idx in 0 ... m.materials.length ) lib.makeMaterial(m, m.materials[idx], loadTexture.bind( def, BASE, idx ) )]);
			}
			obj.name = m.name;
			obj.defaultTransform = m.position.toMatrix();
			objs.push(obj);
			var p = objs[m.parent];
			if( p != null ) p.addChild(obj);
		}
		var o = objs[0];
		if( o != null )
			o.modelRoot = true;
		return o;
	}

	function loadTexture( def: ModelDef, slot: TextureSlot, idx: Int, originalPath: String )
	{
		if( def.materials != null && def.materials[idx] != null )
		{
			switch( slot )
			{
				case BASE:
					if( def.materials[idx].base != null )
						return hxd.Res.load( def.materials[idx].base ).toTexture();
				default:
					throw("Unmatched");
			}
		}

		return hxd.Res.load( originalPath ).toTexture();
	}
/*
	function makeMaterial( model : Model, mid : Int, loadTexture : String -> h3d.mat.Texture )
	{
		var m = header.materials[mid];
		var mat = h3d.mat.MaterialSetup.current.createMaterial();
		mat.name = m.name;
		if( m.diffuseTexture != null ) {
			mat.texture = loadTexture(m.diffuseTexture);
			if( mat.texture == null ) mat.texture = h3d.mat.Texture.fromColor(0xFF00FF);
		}
		if( m.specularTexture != null )
			mat.specularTexture = loadTexture(m.specularTexture);
		if( m.normalMap != null )
			mat.normalMap = loadTexture(m.normalMap);
		mat.blendMode = m.blendMode;
		mat.model = resource;
		var props = h3d.mat.MaterialSetup.current.loadMaterialProps(mat);
		if( props == null ) props = mat.getDefaultModelProps();
		mat.props = props;
		return mat;
	}

*/

}