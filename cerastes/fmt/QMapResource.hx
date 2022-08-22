package cerastes.fmt;

import haxe.io.BytesOutput;
import h3d.Vector;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;
import hxd.res.Loader;

import hxd.res.Resource;

class QMapResource extends Resource
{
	static var minVersion = 1;
	static var version = 1;

	var data: String; // @todo

	public function toObject(?parent = null)
	{

		return null;
	}

	public function getData()
	{
		if (data != null) return data;



		//var u = new haxe.Unserializer(entry.getText());
		//data = u.unserialize();

//		data = CDParser.parse( entry.getText(), CUIFile );

/*
		var parser = new json2object.JsonParser<CUIFile>(); // Creating a parser for Cls class
		parser.fromJson(entry.getText(), entry.name); // Parsing a string. A filename is specified for errors management
		data = parser.value; // Access the parsed class
		var errors:Array<json2object.Error> = parser.errors;
		for( e in errors )
		{
			Utils.warning(json2object.ErrorUtils.convertError(e) );
		}*/

		return data;
	}
}