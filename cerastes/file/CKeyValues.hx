package cerastes.file;

import haxe.ds.StringMap;
import haxe.Constraints.IMap;

enum ParserState {
	NONE;
	KEY;
	VALUE;
	BLOCK;
}

@:autoBuild( cerastes.macros.CKeyValues.build() )
interface Packable
{
	public function unpack( kv: cerastes.file.CKeyValues ): Void;
}

class CKeyValues
{
	static final QUOTE = '"';
	static final BLOCK_BEGIN = "{";
	static final BLOCK_END = "}";

	var pos = 0;
	var	text = "";
	var state: ParserState = NONE;

	var key = "";
	var value = "";

	var parseError = false;

	public var kv: Map<Any, Any>;

	public function new(?text: String) {
		this.text = text;
		kv = new Map<Any, Any>();
	}

	public function get( ...keys: String ) : String
	{
		var subkv: Map<Any, Any> = kv;
		for( idx in 0 ... keys.length )
		{
			var k = keys[idx];
			trace(k);
			if( k == "int" )
				trace(kv);
			if( !subkv.exists( k ) )
				return null;

			if( idx == keys.length - 1)
				return subkv[k];
			else
				subkv = subkv[k];

		}

		return null;

	}



	// ------------------------------------------------------------------------------------------------
	// Read
	// ------------------------------------------------------------------------------------------------
	public static function parse<@:const T:Packable>( text: String, c: Class<T> ) : T
	{
		var kv = new CKeyValues(text);
		var out =  Type.createInstance( c,[]);
		var packable: Packable = cast out;

		kv.read();
		packable.unpack( kv );



		return out;
	}

	function applyKV(object: Any, kv: CKeyValues )
	{
	}

	function read( map: Map<Any, Any> = null )
	{
		if( parseError ) return;

		while( pos < text.length )
		{
			skipWhitespace();
			var c = text.charAt(pos);
			if( c == "}" || pos >= text.length) return;

			var key = readKey();
			skipWhitespace();

			var c = text.charAt(pos++);
			switch( c )
			{
				case '{':

					var subkv;
					if( map == null )
						subkv = this.kv;
					else
					{
						subkv = new Map<Any, Any>();
						map.set(key, subkv );
					}

					read(subkv);

					require("}");


				case '[':
					trace("arr");
					var subArray = new Array<Any>();

					skipWhitespace();
					var next = text.charAt(pos);
					while( next != ']')
					{
						if( parseError ) return;
						subArray.push( readValue() );
						skipWhitespace();
						next = text.charAt(pos);
					}
					map.set(key, subArray);

					require("]");


				default:
					pos--;
					map.set(key, readValue());

			}
		}
	}

	function readValue()
	{
		skipWhitespace();
		if( pos > text.length )
		{
			error("Unexpected end of file");
			return null;
		}

		var value = "";
		var c = text.charAt(pos++);
		if( c == '"')
		{
			// It's a string, read until the first non escaped quote
			var escape = 0;
			c = '';
			do
			{
				value += c;

				if( c == '\\')
					escape++;
				else
					escape = 0;

				c = text.charAt(pos++);
			}
			while( c != '"' || ( c == '"' && escape % 2 == 1 ) );

		}
		else if( c == "n" ) // Null
		{
			pos += 3;
			value = null;
		}
		else
		{
			var start = pos-1;
			var end = start;
			while( isNumeric(StringTools.fastCodeAt(text, end++)) )
				end++;

			value = text.substr(start, end - pos);
			pos = end;
		}


		trace( 'v: ${value}' );
		return value;
	}

	function readKey()
	{
		var start = pos;
		var end = start;
		while( isKey(StringTools.fastCodeAt(text, end)) )
			end++;

		var key = text.substr(pos, end - pos);

		pos = end;

		require(":");

		trace( 'k: ${key}' );
		return key;

		// advance pointer to :, assert nothing but whitespace exists

	}

	function require(c: String )
	{
		skipWhitespace();

		if( text.charAt(pos++) != c)
		{
			error('Expected "${c}", got "${text.charAt(pos-1)}"');
			return false;
		}

		return true;

	}

	function error(str: String )
	{
		parseError = true;
		// figure out line number
		var line = 1;
		var offsetPos = 0;
		for( p in 0 ... pos )
		{
			if( StringTools.fastCodeAt(text, p) == 10 )
			{
				line++;
				offsetPos = pos;
			}
		}

		Utils.error('CKV parse error at ${line}:${pos - offsetPos} : ${str}');
	}

	function skipWhitespace()
	{
		while(isWhitespace(  StringTools.fastCodeAt(text, pos) ) && pos < text.length)
			pos++;
	}

	inline function isWhitespace(c: Int)
	{
		return (c > 8 && c < 14) || c == 32;
	}

	inline function isColon(l: Int)
	{
		return l == 58;
	}

	inline function isKey(l: Int)
	{
		// A-Z a-z 0-9 - _
		return ( l >= 65 && l <= 90 ) || ( l >= 97 && l <= 122 ) || ( l >= 48 && l <= 57 ) || l == 45 || l == 95;
	}

	inline function isNumeric(l: Int)
	{
		// 0-9 .
		return ( l >= 48 && l <= 57 ) || l == 46;
	}

	// ------------------------------------------------------------------------------------------------
	// Write
	// ------------------------------------------------------------------------------------------------

	public static function stringify( object: Any, rootKey: String = "root" )
	{
		var kv = new CKeyValues("");
		kv.writeKeyValue(rootKey, object );

		return @:privateAccess kv.text;
	}

	function writeKeyValue( key: String, object: Any, tabIndent: Int = 0 )
	{
		writeKey( key, tabIndent );
		writeValue( object, tabIndent );
	}

	function writeKey( key: String, tabIndent: Int = 0 )
	{
		text += '${tabs(tabIndent)}${key}: ';
	}

	function writeValue( value: Any, tabIndent: Int = 0  ): Void
	{

		switch (Type.typeof(value)) {
			case TInt | TFloat | TBool | TNull:
				text += '${value}\n';

			case TClass(String):
				text += '"${ StringTools.replace(value, '"', '\\\\"') }"\n';

			case TClass(Array):
				text += '[\n';
				var array: Array<Any> = cast value;
				for( a in array )
				{
					text += '${tabs(tabIndent+1)}';
					writeValue(a, tabIndent+1);
				}
				text += '${tabs(tabIndent)}]\n';
			case TClass(StringMap) | TClass(haxe.ds.IntMap) | TClass( haxe.ds.ObjectMap ) | TClass( haxe.ds.EnumValueMap ):
				text += '{\n';
				var map: Map<Any, Any> = cast value;
				for( key => value in map )
				{
					writeKey( key, tabIndent+1 );
					writeValue( value, tabIndent+1 );
				}
				text += '${tabs(tabIndent)}}\n';
			case TClass(_):
				text += '{\n';

				var fields = Reflect.fields(value);

				writeKey("__hxcls", tabIndent+1);
				writeValue( Type.getClassName( Type.getClass( value ) ) );

				for( fields in fields )
				{
					var value = Reflect.getProperty(value, fields);
					writeKey( fields, tabIndent+1 );
					writeValue( value, tabIndent+1 );
				}
				text += '${tabs(tabIndent)}}\n';



			case _:
				throw "Unsupported... for now?";
		}


	}

	static inline function tabs(count: Int ): String
	{
		var out = "";
		for( i in 0...count )
			out += "\t";

		return out;
	}

}