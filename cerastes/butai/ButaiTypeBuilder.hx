package cerastes.butai;

import haxe.Json;
import haxe.macro.Context;
import haxe.macro.Expr;
using haxe.macro.Tools;

/**
 * Hello future person!
 *
 * This code was adapted from a much less sane version I wrote for Articy. It is
 * the child of dragons. It's certainly much cuter, and its claws may only go
 * skin deep, I still strongly implore you to actually read up on how Haxe macros
 * work instead of trying to learn anything from this.
 *
 * -Chris Kadar, 2019.
 */


abstract Id(String)
{
	inline function new(key) this = key;

	public function get<T>() : Null<T>
	{
		var fun = Type.resolveClass("db.Butai");

		return Reflect.callMethod(fun,  Reflect.field(fun, "lookup"), [this]);
	}

    @:from static function fromString(key:String):Id {

        return new Id(key);
    }
}

typedef ButaiProperty = {
	name: String,
	type: String,
	?label: String,
	?inputType: String,
	?validator: String,
	?option: Array<{label: String, value: String}>,
}

typedef ButaiNodeConnection = {
	name: String,
	?label: String
}

typedef ButaiNodeDefinition = {
	type: String,
	?description: String,
	?label: String,
	?icon: String,

	outputs: Array<ButaiNodeConnection>,
	inputs: Array<ButaiNodeConnection>,
	properties: Array<ButaiProperty>,
}

typedef ButaiNodeFile = {
	nodePackage: String,
	nodes: Array<ButaiNodeDefinition>
}

/* ======================================== */

typedef ButaiSaveProperty = {
	name: String,
	value: Dynamic,
}

typedef ButaiSaveConnection = {
	name: String,
	targets: Array<{ id: Id, port: String }>,
}

typedef ButaiSaveNode = {
	id: String,
	type: String,
	parent: String,
	properties: Array<ButaiSaveProperty>,
	connections: {
		inputs: Array<ButaiSaveConnection>,
		outputs: Array<ButaiSaveConnection>,
	},
}

typedef ButaiSaveFile = {
	nodes: Array<ButaiSaveNode>,
}

/* ======================================== */
@:keepSub
class ButaiNode
{
	public var id: Id;
	public var parent: Id;
	public var type: String;

	public var inputs = new Array<{ name: String, target: Id }>();
	public var outputs = new Array<{ name: String, target: Id }>();
}



class ButaiTypeBuilder
{

	#if macro
	static function toTypePath(s:String, ?params):TypePath
	{
		var parts = s.split('.');
		var name = parts.pop(),
		sub = null;

		if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B)
		{
			sub = name;
			name = parts.pop();
			if(sub == name)
				sub = null;
		}

		return 	{
			name: name,
			pack: parts,
			params: params == null ? [] : params,
			sub: sub
		};
	}
	#end

	public static function build(nodeFile:String, ?typeName : String)
	{
		#if !macro
		throw "This can only be called in a macro";
		#else
		var pos = Context.currentPos();

		var path = try Context.resolvePath(nodeFile) catch( e : Dynamic ) null;
		if( path == null )
		{
			var r = Context.definedValue("resourcesPath");
			if( r != null )
			{
				r = r.split("\\").join("/");
				if( !StringTools.endsWith(r, "/") ) r += "/";
				try path = Context.resolvePath(r + nodeFile) catch( e : Dynamic ) null;
			}
		}
		if( path == null )
			try path = Context.resolvePath("res/" + nodeFile) catch( e : Dynamic ) null;
		if( path == null )
			Context.error("File not found " + nodeFile, pos);

		var json : ButaiNodeFile = Json.parse( sys.io.File.getContent( path ) );

		var r_chars = ~/[^A-Za-z0-9_]/g;

		function makeTypeName( name : String ) {
			var t = r_chars.replace(name, "_");
			t = t.substr(0, 1).toUpperCase() + t.substr(1);
			return t;
		}

		function fieldName( name : String ) {
			var t = r_chars.replace(name, "_");
			t = t.substr(0, 1).toLowerCase() + t.substr(1);
			return t;
		}
		var types = new Array<haxe.macro.Expr.TypeDefinition>();
		var curMod = Context.getLocalModule().split(".");
		var modName = curMod.pop();
		if( typeName != null )
			modName = typeName;

		var baseEntityFields : Array<haxe.macro.Expr.Field>;

		for( typeDef in json.nodes )
		{


			var tname = makeTypeName(typeDef.type );
			var fields : Array<haxe.macro.Expr.Field> = [];

			var props = typeDef.properties;
			if( props != null )
			{
				for( fieldDef in props )
				{
					var cname = fieldDef.name;

					var fkind : FieldType = null;
					var t = switch( fieldDef.type )
					{
						case "Int": macro : Int;
						case "Float": macro : Float;
						case "Bool": macro : Bool;
						case "String": macro : String;
						default: fieldDef.type.toComplex();
					}

					if( fkind == null )
						fkind = FVar(t);




					fields.push({
						name : cname,
						pos : pos,
						kind : fkind,
						access : [APublic],
					});
				}
			}
			var ckind = TDClass( toTypePath( "cerastes.butai.ButaiTypeBuilder.ButaiNode" ) );

			var def = tname;
			types.push({
				pos : pos,
				name : def,
				pack : curMod,
				kind : ckind,
				fields : fields,
			});


			//break;
		}

		var globalFields = new Array<haxe.macro.Expr.Field>();
		var assigns = [];

		for( typeDef in json.nodes )
		{

			var tname = makeTypeName(typeDef.type);
			var t = tname.toComplex();
			var fname = fieldName(typeDef.type);

			globalFields.push({
				name : fname,
				pos : pos,
				access : [APublic, AStatic],
				kind : FVar(macro : cerastes.butai.ButaiTypeBuilder.Index<$t>),
			});
			assigns.push(macro $i { fname } = new cerastes.butai.ButaiTypeBuilder.Index<$t>(root, $v { tname } ));

		}

		types.push({
			pos : pos,
			name : modName,
			pack : curMod,
			kind : TDClass(),
			fields : (macro class {

				public static var idMap = new Map<String, Dynamic>();

				public static function load( content : String ) {

					var root = haxe.Json.parse( content );
					idMap = new Map<String, Dynamic>();

					{$a{assigns}};
				}

				public static function lookup( id : String ) : Null<Dynamic> {

					if( idMap.exists( id ) )
						return idMap[id];

					return null;
				}

				public static function find( type: String, parent: String ) : Null<Dynamic> {

					for( node in idMap)
					{
						if( node.type == type && node.parent == parent )
							return node;


					}

					return null;
				}
			}).fields.concat(globalFields),
		});


		var mpath = Context.getLocalModule();

		//trace("...Done... generating types...");

		Context.defineModule(mpath, types);
		Context.registerModuleDependency(mpath, path);

		#if (haxe_ver >= 3.2)
		return macro : Void;
		#else
		return Context.getType("Void");
		#end
		#end
	}
}

class Index<T:{id:Id}>
{
	public var all(default,null) : Array<T>;
	var name : String;


	public function add(json: ButaiSaveNode )
	{
		var butaiType = Type.resolveClass( "db." + name);
		var entry : T = Type.createInstance(butaiType,[]);
		var cls = Type.resolveClass("db.Butai");
		var idMap : Map<String, Dynamic>  = Reflect.field(cls, "idMap" );

		entry.id = json.id;

		if( idMap.exists( cast entry.id ) )
			trace( '!!!! Duplicate node ID ${entry.id}' );
		idMap[cast entry.id] = entry;

		for(property in json.properties )
		{
			try
			{
				Reflect.setField(entry, property.name, property.value );
			}
			catch( e: Dynamic )
			{
				// Look it's just gotta work, right?
				Reflect.setField(entry, property.name, property.value == "true");
			}
			//
			//else

    	}

		var baseNode : ButaiNode = cast entry;

		baseNode.parent = json.parent;
		baseNode.type = json.type;


		for( output in json.connections.outputs )
		{
			for( target in output.targets )
			{
				baseNode.outputs.push( { name: output.name, target: target.id } );
			}
		}

		for( input in json.connections.inputs )
		{
			for( target in input.targets )
			{
				baseNode.inputs.push( { name: input.name, target: target.id } );
			}
		}

		all.push(entry);
	}


	public function new(data:ButaiSaveFile , name) {
		all = new Array<T>();
		this.name = name;

		for( node in data.nodes )
		{
			if( node.type == name )
			{
				add( node );
			}

		}

	}

	public function get( id: Id ) : Null<T>	{
		for( l in all )		{
			if( l.id == id )
				return l;
		}
		return null;
	}
}
