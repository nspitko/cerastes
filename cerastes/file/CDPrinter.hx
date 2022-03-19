package cerastes.file;

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

	function write(k:Dynamic, v:Dynamic) {
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
						write(i, v[i]);
						if (i == last) {
							nind--;
							newl();
							ipad();
						}
					}
					addChar(']'.code);
				} else if (c == haxe.ds.StringMap) {
					mapString(v);
				} else if (c == Date) {
					var v:Date = v;
					quote(v.toString());
				} else
					classString(v);
			case TEnum(_):
				var i:Int = Type.enumIndex(v);
				var e = Type.getEnum(v);
				var t = e.getName();

				add( Std.string( 'enum:${t} $i' ) );
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

	function classString(v:Dynamic) {
		fieldsString(v, Type.getInstanceFields(Type.getClass(v)));
	}

	inline function mapString(v:Map<Any, Any>) {

		fieldsString(v, [ for(k in v.keys() ) k ] );
	}

	inline function objString(v:Dynamic) {
		fieldsString(v, Reflect.fields(v));
	}

	function fieldsString(v:Dynamic, fields:Array<String>) {

		var len = fields.length;
		var last = len - 1;
		var first = true;
		var isMap = false;

		switch(Type.typeof(v)){
			case TClass(c):
				var className = Type.getClassName(c);

				nind++;
				first = false;

				//if( #if flash9 try obj.TJ_noEncode != null catch( e : Dynamic ) false #elseif (cs || java) Reflect.hasField(obj, "TJ_noEncode") #else obj.TJ_noEncode != null #end  ) {
				//	dontEncodeFields = obj.TJ_noEncode();
				//}

				add("cls:");
				add(className);

				if (pretty)
					addChar(' '.code);

				isMap = className == "haxe.ds.StringMap";

				if ( 0 == last) {
					nind--;
					newl();
					ipad();
				}

			default:

		}

		addChar('{'.code);


		for (i in 0...len) {
			var f = fields[i];
			var value;
			if( isMap )
				value = v.get(f);
			else
				value = Reflect.field(v, f);
			if (Reflect.isFunction(value))
				continue;
			if (first) {
				nind++;
				first = false;
			}
			newl();
			ipad();
			add(f);
			if (pretty)
				addChar(' '.code);
			addChar('='.code);
			if (pretty)
				addChar(' '.code);
			write(f, value);
			if (i == last) {
				nind--;
				newl();
				ipad();
			}
		}
		addChar('}'.code);
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