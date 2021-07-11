package cerastes.fmt;

import h2d.Object;
import haxe.Json;
import hxd.res.Resource;

// Cerastes UI

typedef CUIProperties = {
	var key: String;
	var value: String;
}

typedef CUIEntry = {
	var type: String;
	@:optional var props: Array<CUIProperties>;
	@:optional var arguments: Array<CUIProperties>; // Constructor arguments
	@:optional var children: Array<CUIEntry>;

}

typedef CUIFile = {
	var version: Int;
	var entries: Array<CUIEntry>;
}

class CUI extends Resource
{
	var data: CUIFile;

	static var minVersion = 1;
	static var maxSafeVersion = 1;

	public function toObject()
	{
		var data = getData();
		Utils.assert( data.version <= maxSafeVersion, "Warning: CUI generated with newer version than this parser supports" );
		Utils.assert( data.version >= minVersion, "Warning: CUI version marked incompatible with this parser; will likely fail" );

		var root = new Object();

		for( e in data.entries )
			recursiveCreateObjects(e, root);
	}

	function recursiveCreateObjects( entry: CUIEntry, parent: Object )
	{
		var e = createObject(entry.type, entry.arguments);
		parent.addChild(e);

		for( p in entry.props )
			setProperty( e, p.key, p.value );

		for( c in entry.children )
			recursiveCreateObjects( c, e );
	}

	function createObject( type: String, arguments: Array<CUIProperties> ) : h2d.Object
	{
		var t = Type.resolveClass( type );

		var obj: Object;

		switch( type )
		{
			default:
				obj = Type.createInstance(t, []);
		}
		return obj;
	}

	function setProperty( obj: Object, property: String, value: String )
	{

		switch( property )
		{
			case "x": obj.x = Std.parseFloat( value );
			case "y": obj.y = Std.parseFloat( value );
			//case ""

			default:
				Utils.warning('CUI specifies unknown property ${property}; Ignoring!!');

		}
	}

	function getData() : CUIFile
	{
		if (data != null) return data;
		var fs = new hxd.fs.FileInput(entry);
		data = Json.parse( fs.readAll().toString() );
		fs.close();
		return data;
	}
}