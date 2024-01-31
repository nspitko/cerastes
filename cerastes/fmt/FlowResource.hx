package cerastes.fmt;

import cerastes.flow.Flow.FlowContext;
import cerastes.flow.Flow.FlowRunner;
import cerastes.flow.Flow.FlowFile;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import h2d.ScaleGrid;
import h2d.Tile;
import haxe.EnumTools;
import h3d.Vector4;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;
import h2d.Bitmap;
import hxd.res.BitmapFont;
import h2d.Font;
import hxd.res.Loader;
import h2d.Object;
import haxe.Json;
import hxd.res.Resource;


class FlowResource extends Resource
{
	var data: FlowFile;

	static var minVersion = 1;
	static var version = 1;


	public function toFlow( ?context: FlowContext, ?pos:haxe.PosInfos )
	{
		var data = getData();

		return new FlowRunner( this, context, pos );
	}


	public static function write( obj: FlowFile, file: String )
	{

		//var s = new hxbit.Serializer();
		//var bytes = s.serialize(cui);

		//var txt = Json.print( "CSDFile", csd);
		var txt = Json.stringify( obj, null, "\t" );


		#if hl
		sys.io.File.saveContent(Utils.fixWritePath(file, "cbl"),txt);
		#end
	}


	public function getData( ?cache: Bool = true ) : FlowFile
	{
		if (data != null && cache) return data;

		//var u = new hxbit.Serializer();
		//data = u.unserialize(entry.getBytes(), CSDFile);
		//data = cast Json.parse( "cerastes.fmt.SpriteResource.CSDFile", entry.getText()  );
		var d : FlowFile = CDParser.parse( entry.getText(), FlowFile );
		if( cache )
			data = d;

		Utils.assert( d.version <= version, 'Warning: Flow file generated with newer version than this parser supports (Have: ${d.version}, known: ${version})' );
		Utils.assert( d.version >= minVersion, 'Warning: Flow file version newer than parser understands; parsing will probably fail!  (Have: ${d.version}, known: ${version})' );


		return d;
	}
}