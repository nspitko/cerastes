package cerastes.macros;

import cerastes.butai.ButaiTypeBuilder.ButaiNodeFile;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Json;
#if macro
using haxe.macro.Tools;
#end

typedef ClassKey = {};

// Generates callback hooks for Butai classes; only makes sense when using Callbackgenerator
class ButaiCallbackGenerator
{
	#if macro
	macro public static function build(nodeFile:String):Array<Field>
	{
		// Check to see if Butai typex exit yet, else abort
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();


		try{
			var y = Context.resolveType(TPath({
				name: "LabelNode",
				pack: ["db"]
			}), pos);

			if( y == null )
				return fields;
		}
		catch(e)
		{
			trace(e);
			return fields;
		}

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



		for( node in json.nodes)
		{
			var t = TPath({
				name: node.type,
				pack: ["db"]
			});
			var fnCallback: Function = {
				expr: null,
				args: [
					{ name:'node', type: t },
				],
				ret: macro: Bool
			};

			fields.push({
				name: 'on${node.type}',
				access: [Access.APrivate],
				kind: FieldType.FFun(fnCallback),
				pos: Context.currentPos(),
				meta: [{name: ":callback", pos: pos}]
			});
		}


		return fields;
	}
	#end

}


class CallbackGenerator
{
	#if macro
	macro public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();
		if( fields == null )
			return fields;

		var i = fields.length;
		while (i > 0)
		{
			var field = fields[--i];
			// Only modify replicated fields.
			var found = false;
			for( m in field.meta )
			{
				if( m.name == ":callback" )
					fields = fields.concat( addCallbackFields( field, false )  );
				if( m.name == ":callbackStatic" )
					fields = fields.concat( addCallbackFields( field, true ) );
			}
		}

		return fields;
	}

	static function addCallbackFields( field: Field, isStatic: Bool ) : Array<Field>
	{
		var append: Array<Field> = [];

		switch (field.kind)
		{
			case FFun( func ):
				// Add the listener field

				//trace('processing ${field.name}');
				var fieldNameUpper = field.name.substr(0,1).toUpperCase() + field.name.substr(1);

				var args = [for (arg in func.args) arg.type ] ;
				//args.push(TOptional(TPath({ pack: [], name: "Bool" }))); // Handled?
				args.push(TPath({ pack: [], name: "Bool" })); // Handled?
				var callbackType = TFunction(args, macro: Bool);
				var mapType: TypePath = {
					name: "Map",
					pack: ["haxe", "ds"],
					params: [
						TPType(
							TPath({
								pack: ["cerastes","macros"],
								name: "Callbacks",
								sub: "ClassKey"
							})
						),
						TPType( callbackType )

					]
				};

				var accessPrivate = isStatic ?  [Access.APrivate, Access.AStatic] :  [Access.APrivate];
				var accessPublic = isStatic ?  [Access.APublic, Access.AStatic] :  [Access.APublic];

				append.push({
					name: "_listeners_" + field.name,
					access: accessPrivate,
					kind: FieldType.FVar( TPath(mapType), macro []), // @todo specify this better
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});

				var fnAddListener: Function = {
					expr: macro {
						if( $i{"_listeners_" + field.name}.exists( owner ) )
							return false;

						$i{"_listeners_" + field.name}.set( owner, fn );
						return true;
					},
					args: [
						{ name:'owner', type: macro: cerastes.macros.Callbacks.ClassKey },
						{ name:'fn', type: callbackType }
					],
					ret: macro: Bool
				};

				append.push({
					name: 'register${fieldNameUpper}',
					access: accessPublic,
					kind: FieldType.FFun(fnAddListener),
					pos: Context.currentPos(),
				});

				var fnRemoveListener: Function = {
					expr: macro {
						return $i{"_listeners_" + field.name}.remove( owner );
					},
					args: [
						{ name:'owner', type: macro: cerastes.macros.Callbacks.ClassKey }
					],
					ret: macro: Bool
				};

				append.push({
					name: 'unregister${fieldNameUpper}',
					access: accessPublic,
					kind: FieldType.FFun(fnRemoveListener),
					pos: Context.currentPos(),
				});

				// Finally, fill out the function body

				var argNames = [for (arg in func.args) macro $i{arg.name}];
				argNames.push( macro $i{"handled"});


				func.expr = macro {
					var handled = false;
					for( l in $i{"_listeners_" + field.name})
					{
						handled = handled || l($a{argNames});
					}

					return handled;
				};


			default:
				throw "Only functions can be marked as callbacks!";
		}



		return append;
	}

	#end
}