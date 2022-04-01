package cerastes.file;

import haxe.rtti.Meta;
import haxe.EnumTools;

/**
 An implementation of JSON printer in Haxe.

	This class is used by `haxe.Json` when native JSON implementation
	is not available.

	@see https://haxe.org/manual/std-Json-encoding.html
**/
class CDPrinter {
	/**
	 Encodes `o`'s value and returns the resulting string.

		If `replacer` is given and is not null, it is used to retrieve
		actual object to be encoded. The `replacer` function takes two parameters,
		the key and the value being encoded. Initial key value is an empty string.

		If `space` is given and is not null, the result will be pretty-printed.
		Successive levels will be indented by this string.
	**/
	static public function print(o:Dynamic, ?replacer:(key:Dynamic, value:Dynamic) -> Dynamic, ?space:String = "\t"):String {
		var printer = new CDPrinter(replacer, space);
		printer.write("", o);
		return printer.buf.toString();
	}

	var buf:#if flash flash.utils.ByteArray #else StringBuf #end;
	var replacer:(key:Dynamic, value:Dynamic) -> Dynamic;
	var indent:String;
	var pretty:Bool;
	var nind:Int;

	function new(replacer:(key:Dynamic, value:Dynamic) -> Dynamic, space:String) {
		this.replacer = replacer;
		this.indent = space;
		this.pretty = space != null;
		this.nind = 0;

		#if flash
		buf = new flash.utils.ByteArray();
		buf.endian = flash.utils.Endian.BIG_ENDIAN;
		buf.position = 0;
		#else
		buf = new StringBuf();
		#end
	}

	inline function ipad():Void {
		if (pretty)
			add(StringTools.lpad('', indent, nind * indent.length));
	}

	inline function newl():Void {
		if (pretty)
			addChar('\n'.code);
	}

	function write(k:Dynamic, v:Dynamic, ?assumeType: String) {
		if (replacer != null)
			v = replacer(k, v);

		switch (Type.typeof(v)) {
			case TUnknown:
				add('"???"');
			case TObject:
				objString(v);
			case TInt:
				add(#if (jvm || hl) Std.string(v) #else v #end);
			case TFloat:
				add(Math.isFinite(v) ? Std.string(v) : 'null');
			case TFunction:
				add('"<fun>"');
			case TClass(c):
				if (c == String)
					quote(v);
				else if (c == Array) {
					var v:Array<Dynamic> = v;
					addChar('['.code);

					var len = v.length;
					var last = len - 1;
					for (i in 0...len) {
						if (i == 0)
							nind++;
						newl();
						ipad();
						write(i, v[i], assumeType);
						if (i == last) {
							nind--;
							newl();
							ipad();
						}
					}
					addChar(']'.code);
				} else if (c == haxe.ds.StringMap) {
					mapString(v, assumeType);
				} else if (c == haxe.ds.IntMap) {
					mapInt(v, assumeType);
				} else if (c == Date) {
					var v:Date = v;
					quote(v.toString());
				} else
					classString(v, assumeType);
			case TEnum(_):
				var i:Int = Type.enumIndex(v);
				var e = Type.getEnum(v);
				var t = e.getName();

				add( Std.string( 'enum:${t}.$v' ) );
			case TBool:
				add(#if (php || jvm || hl) (v ? 'true' : 'false') #else v #end);
			case TNull:
				add('null');
		}
	}

	extern inline function addChar(c:Int) {
		#if flash
		buf.writeByte(c);
		#else
		buf.addChar(c);
		#end
	}

	extern inline function add(v:String) {
		#if flash
		// argument is not always a string but will be automatically casted
		buf.writeUTFBytes(v);
		#else
		buf.add(v);
		#end
	}

	function classString(v:Dynamic, assumeType: String) {
		fieldsString(v, Type.getInstanceFields(Type.getClass(v)), assumeType);
	}

	inline function mapString(v:Map<Any, Any>, assumeType: String) {

		var keys:Array<String> = [ for(k in v.keys() ) k ];
		keys.sort( Reflect.compare );
		fieldsString(v, keys, assumeType );
	}

	inline function mapInt(v:haxe.ds.IntMap<Any>, assumeType: String)
	{
		var first = true;

		if( assumeType != "haxe.ds.IntMap" )
		{
			add("cls:haxe.ds.IntMap");

			if (pretty)
				addChar(' '.code);
		}

		addChar('{'.code);

		nind++;
		for (key => value in v)
		{
			newl();
			ipad();
			add('${key}');
			if (pretty)
				addChar(' '.code);
			addChar('='.code);
			if (pretty)
				addChar(' '.code);
			write('${key}', value);
		}
		nind--;
		newl();
		ipad();
		addChar('}'.code);

	}

	inline function objString(v:Dynamic) {
		fieldsString(v, Reflect.fields(v));
	}

	function fieldsString(v:Dynamic, fields:Array<String>, ?assumedType: String) {

		var len = fields.length;
		var first = true;
		var isMap = false;

		switch(Type.typeof(v)){
			case TClass(c):
				var className = Type.getClassName(c);

				if( assumedType != className )
				{
					add("cls:");
					add(className);

					if (pretty)
						addChar(' '.code);
				}

				isMap = className == "haxe.ds.StringMap" || className == "haxe.ds.IntMap";


			default:

		}

		addChar('{'.code);


		nind++;

		for (i in 0...len) {
			var f = fields[i];

			if( getMetaForField(f, "noSerialize", Type.getClass( v ) ) )
				continue;

			var assumeType = getMetaForField(f, "serializeType", Type.getClass( v ) );
			var alwaysSerialize: Bool = getMetaForField(f, "serializeAlways", Type.getClass( v ) );

			var value : Any;
			if( isMap )
				value = v.get(f);
			else
				value = Reflect.field(v, f);
			if (Reflect.isFunction(value))
				continue;

			if( !alwaysSerialize )
			{
				switch (Type.typeof(value))
				{
					case TNull:
						continue;
					case TInt:
						if( value == 0 )
							continue;
					case TFloat:
						if( value == 0.0 )
							continue;
					case TBool:
						if( value == false )
							continue;

					default:

				}
			}


			newl();
			ipad();
			add(f);
			if (pretty)
				addChar(' '.code);
			addChar('='.code);
			if (pretty)
				addChar(' '.code);
			write(f, value, assumeType);
		}
		nind--;
		newl();
		ipad();
		addChar('}'.code);
	}

	function getMetaForField( f: String, m: String, cls: Class<Dynamic> ) : Any
	{
		var meta: haxe.DynamicAccess<Dynamic> = null;
		if( cls != null )
			meta = Meta.getFields( cls );

		if( meta != null && meta.exists( f ) )
		{
			var metadata: haxe.DynamicAccess<Dynamic> = meta.get(f);

			if( metadata.exists(m) )
			{
				var val = metadata.get(m);
				if( val == null )
					return true;
				else
					return val[0];
			}

		}

		cls = Type.getSuperClass( cls );
		if( cls != null )
			return getMetaForField(f, m, cls );

		return null;

	}

	function quote(s:String) {
		#if neko
		if (s.length != neko.Utf8.length(s)) {
			quoteUtf8(s);
			return;
		}
		#end
		addChar('"'.code);
		var i = 0;
		var length = s.length;
		#if hl
		var prev = -1;
		#end
		while (i < length) {
			var c = StringTools.unsafeCodeAt(s, i++);
			switch (c) {
				case '"'.code:
					add('\\"');
				case '\\'.code:
					add('\\\\');
				case '\n'.code:
					add('\\n');
				case '\r'.code:
					add('\\r');
				case '\t'.code:
					add('\\t');
				case 8:
					add('\\b');
				case 12:
					add('\\f');
				default:
					#if flash
					if (c >= 128)
						add(String.fromCharCode(c))
					else
						addChar(c);
					#elseif hl
					if (prev >= 0) {
						if (c >= 0xD800 && c <= 0xDFFF) {
							addChar((((prev - 0xD800) << 10) | (c - 0xDC00)) + 0x10000);
							prev = -1;
						} else {
							addChar("□".code);
							prev = c;
						}
					} else {
						if (c >= 0xD800 && c <= 0xDFFF)
							prev = c;
						else
							addChar(c);
					}
					#else
					addChar(c);
					#end
			}
		}
		#if hl
		if (prev >= 0)
			addChar("□".code);
		#end
		addChar('"'.code);
	}

	#if neko
	function quoteUtf8(s:String) {
		var u = new neko.Utf8();
		neko.Utf8.iter(s, function(c) {
			switch (c) {
				case '\\'.code, '"'.code:
					u.addChar('\\'.code);
					u.addChar(c);
				case '\n'.code:
					u.addChar('\\'.code);
					u.addChar('n'.code);
				case '\r'.code:
					u.addChar('\\'.code);
					u.addChar('r'.code);
				case '\t'.code:
					u.addChar('\\'.code);
					u.addChar('t'.code);
				case 8:
					u.addChar('\\'.code);
					u.addChar('b'.code);
				case 12:
					u.addChar('\\'.code);
					u.addChar('f'.code);
				default:
					u.addChar(c);
			}
		});
		buf.add('"');
		buf.add(u.toString());
		buf.add('"');
	}
	#end
}