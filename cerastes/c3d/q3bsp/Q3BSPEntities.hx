package cerastes.c3d.q3bsp;

import haxe.rtti.Meta;
import cerastes.c3d.map.SerializedMap.EntityDef;
import haxe.io.Bytes;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPEffectDef;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;

enum ParseScope {
	Key;
	Value;
}

class Q3BSPEntities
{
	static var bsp: BSPFileDef;


	static var curEntity: Q3BSPEntityData;
	static var entities: Array<Q3BSPEntityData> = [];

	static var buf: Bytes;

	static var cur = 0;

	static var world: World;

	static var classMap: Map<String, Class<Dynamic>>;

	static function spawnEntities( bsp: BSPFileDef, world: World )
	{
		this.bsp = bsp;
		this.world = world;
		buf = haxe.io.Bytes.ofString( bsp.entities );

		parse();

		spawnEntities();

		for( e in entities )
		{
			spawnEntity(e);
		}
	}

	public static function spawnEntity( def: Q3BSPEntityData )
	{
		ensureClassMap();

		var className = def.getProperty("classname");
		if( className == null )
		{
			Utils.warning('Entity def missing classname!!!');
			return null;
		}

		if( className.indexOf("world") != -1 )
		{
			trace(className);
		}

		var cls: Class<Dynamic> = classMap.get( className );

		if( cls != null )
		{
			var entity: QEntity = Type.createInstance(cls,[]);
			@:privateAccess entity.create(def, world);
			world.addChild(entity);



			return entity;
		}

		//Utils.warning('Could not find class def for ${className}');
		return null;
	}

	static function parse()
	{

		var c: Int;
		var scope: ParseScope = Key;

		var k: String = null;
		var v: String= null;


		while( cur < bsp.entities.length )
		{
			var c = buf.get(cur++);
			if( isSpace( c ) )
				continue;

			if( c == '{'.code )
			{
				curEntity = {};
				scope = Key;
			} else if( c == '}'.code )
			{
				entities.push( curEntity );
			}
			else if ( c == '"'.code )
			{
				switch( scope )
				{
					case Key:
						k = readToken();
						scope = Value;
					case Value:
						v = readToken();
						scope = Key;
						curEntity.props.set(k,v);
						k = v = null;
				}
			}


		}
	}

	static function readToken()
	{
		var out = new StringBuf();
		var end = false;
		while( !end )
		{
			var c = buf.get(cur++);
			if( c == '"'.code )
			{
				return out.toString();
			}

			out.addChar(c);
		}

		return "";
	}

	// ----------------------------------------------------------------------------
	static inline function isSpace(code: Int)
	{
		return code == ' '.code || code == '\t'.code || code == '\r'.code || code == '\n'.code;
	}

	static function ensureClassMap()
	{
		if( classMap != null )
			return;

		classMap = [];

		var classList = CompileTime.getAllClasses(Entity);
		for( c in classList )
		{
			var clsMeta = Meta.getType(c);
			var defs = clsMeta.qClass;
			if( defs != null )
			{
				for( d in defs )
				{
					classMap.set(d.name,c);
				}
			}
		}
	}
}