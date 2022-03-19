package cerastes.file;

import haxe.rtti.Meta;

class CDParser {
	/**
		Parse a Cerastes Key Values file. This format is roughly similar to JSON (and indeed the parser
			is based off a JSON parser) but is more forgiving in its syntax, as well as supports some
			additional type combinations like maps
	**/
	static public inline function parse<T>(str:String, c: Class<T>):T {
		return new CDParser(str).doParse();
	}

	var str:String;
	var pos:Int;

	function new(str:String) {
		this.str = str;
		this.pos = 0;
	}

	function doParse( ):Dynamic {
		var result = parseRec( );
		var c;
		while (!StringTools.isEof(c = nextChar())) {
			switch (c) {
				case ' '.code, '\r'.code, '\n'.code, '\t'.code:
				// allow trailing whitespace
				default:
					invalidChar();
			}
		}
		return result;
	}

	function parseRec( ):Dynamic {
		var obj: Dynamic = null;

		while (true) {
			var c = nextChar();
			switch (c) {
				case ' '.code, '\r'.code, '\n'.code, '\t'.code:
				// loop
				case '{'.code:
					var field = new StringBuf();
					while (true) {
						var c = nextChar();
						switch (c) {
							case ' '.code, '\r'.code, '\n'.code, '\t'.code:
							// loop
							case '}'.code:
								if (field.length > 0 )
									invalidChar();
								return obj;
							case '='.code:
								if (field == null)
									invalidChar();

								if( field.toString() == "_class" )
								{
									if( obj != null )
										throw("_class must be the first element (for now)");

									var v = parseRec();
									var cls =Type.resolveClass(v);
									if(cls==null) throw "Invalid class name - "+v;
									obj = Type.createEmptyInstance(cls);
								}
								else
								{
									if( obj == null )
										obj = {};

									var rec: Dynamic = parseRec();

									//trace('${field} -> ${rec}');

									if( obj is haxe.ds.StringMap)
										obj.set( field.toString(), rec );
									else
									{
										Reflect.setField(obj, field.toString(), rec );
									}
								}


								field  = new StringBuf();

							default:
								if( ( c >= 65 && c <= 90 ) || ( c >= 97 && c <= 122 ) || ( c >= 48 && c <= 57 ) || c == 95 )
								{
									field.addChar(c);
								}
								else
									invalidChar();
						}
					}
				case 'c'.code:

					var save = pos;
					if (nextChar() != 'l'.code || nextChar() != 's'.code || nextCharNonWS() != ':'.code ) {
						pos = save;
						invalidChar();
					}

					eatWS();

					var classType = parseType();

					eatWS();

					if ( nextChar() != '{'.code )
					{
						pos = save;
						invalidChar();
					}

					var cls =Type.resolveClass(classType.toString());
					if(cls==null) throw "Invalid class name - "+classType;
					obj = Type.createEmptyInstance(cls);

					var field = new StringBuf();
					while (true) {
						var c = nextChar();
						switch (c) {
							case ' '.code, '\r'.code, '\n'.code, '\t'.code:
							// loop
							case '}'.code:
								if (field.length > 0 )
									invalidChar();
								return obj;
							case '='.code:
								if (field == null)
									invalidChar();


								var rec: Dynamic = parseRec();

								if( obj is haxe.ds.StringMap)
									obj.set( field.toString(), rec );
								else
								{
									Reflect.setField(obj, field.toString(), rec );
								}



								field  = new StringBuf();

							default:
								if( ( c >= 65 && c <= 90 ) || ( c >= 97 && c <= 122 ) || ( c >= 48 && c <= 57 ) || c == 95 )
								{
									field.addChar(c);
								}
								else
									invalidChar();
						}
					}
				case '['.code:
					var arr = [], comma:Null<Bool> = null;
					while (true) {
						var c = nextChar();
						switch (c) {
							case ' '.code, '\r'.code, '\n'.code, '\t'.code:
							// loop
							case ']'.code:
								return arr;
							case ','.code:
								// optional!
							default:
								pos--;
								arr.push(parseRec());
								comma = true;
						}
					}
				case 't'.code:
					var save = pos;
					if (nextChar() != 'r'.code || nextChar() != 'u'.code || nextChar() != 'e'.code) {
						pos = save;
						invalidChar();
					}
					return true;
				case 'f'.code:
					var save = pos;
					if (nextChar() != 'a'.code || nextChar() != 'l'.code || nextChar() != 's'.code || nextChar() != 'e'.code) {
						pos = save;
						invalidChar();
					}
					return false;
				case 'n'.code:
					var save = pos;
					if (nextChar() != 'u'.code || nextChar() != 'l'.code || nextChar() != 'l'.code) {
						pos = save;
						invalidChar();
					}
					return null;
				case 'e'.code:
					var save = pos;
					if (nextChar() != 'n'.code || nextChar() != 'u'.code || nextChar() != 'm'.code || nextCharNonWS() != ':'.code) {
						pos = save;
						invalidChar();
					}
					// Parsing an enum!
					var enumType = parseType();
					var enumVal: Int = parseRec();

					//trace('${enumType} -> ${enumVal}');
					var et = Type.resolveEnum( enumType.toString() );
					Utils.assert(et != null, 'Unknown enum type ${enumType}');

					var ev = Type.createEnumIndex(et,  enumVal );
					return ev;


				case '"'.code:
					return parseString();
				case '0'.code, '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code, '8'.code, '9'.code, '-'.code:
					return parseNumber(c);
				default:
					invalidChar();
			}
		}
	}

	function parseType()
	{
		var field = new StringBuf();
		var c = nextCharNonWS();
		while (true) {
			if( ( c >= 65 && c <= 90 ) || ( c >= 97 && c <= 122 ) || ( c >= 48 && c <= 57 ) || c == 95 || c == 46 )
			{
				field.addChar(c);
				c = nextChar();
			}
			else
				break;
		}

		return field;

	}

	function parseString() {
		var start = pos;
		var buf:StringBuf = null;
		#if target.unicode
		var prev = -1;
		inline function cancelSurrogate() {
			// invalid high surrogate (not followed by low surrogate)
			buf.addChar(0xFFFD);
			prev = -1;
		}
		#end
		while (true) {
			var c = nextChar();
			if (c == '"'.code)
				break;
			if (c == '\\'.code) {
				if (buf == null) {
					buf = new StringBuf();
				}
				buf.addSub(str, start, pos - start - 1);
				c = nextChar();
				#if target.unicode
				if (c != "u".code && prev != -1)
					cancelSurrogate();
				#end
				switch (c) {
					case "r".code:
						buf.addChar("\r".code);
					case "n".code:
						buf.addChar("\n".code);
					case "t".code:
						buf.addChar("\t".code);
					case "b".code:
						buf.addChar(8);
					case "f".code:
						buf.addChar(12);
					case "/".code, '\\'.code, '"'.code:
						buf.addChar(c);
					case 'u'.code:
						var uc:Int = Std.parseInt("0x" + str.substr(pos, 4));
						pos += 4;
						#if !target.unicode
						if (uc <= 0x7F)
							buf.addChar(uc);
						else if (uc <= 0x7FF) {
							buf.addChar(0xC0 | (uc >> 6));
							buf.addChar(0x80 | (uc & 63));
						} else if (uc <= 0xFFFF) {
							buf.addChar(0xE0 | (uc >> 12));
							buf.addChar(0x80 | ((uc >> 6) & 63));
							buf.addChar(0x80 | (uc & 63));
						} else {
							buf.addChar(0xF0 | (uc >> 18));
							buf.addChar(0x80 | ((uc >> 12) & 63));
							buf.addChar(0x80 | ((uc >> 6) & 63));
							buf.addChar(0x80 | (uc & 63));
						}
						#else
						if (prev != -1) {
							if (uc < 0xDC00 || uc > 0xDFFF)
								cancelSurrogate();
							else {
								buf.addChar(((prev - 0xD800) << 10) + (uc - 0xDC00) + 0x10000);
								prev = -1;
							}
						} else if (uc >= 0xD800 && uc <= 0xDBFF)
							prev = uc;
						else
							buf.addChar(uc);
						#end
					default:
						throw "Invalid escape sequence \\" + String.fromCharCode(c) + " at position " + (pos - 1);
				}
				start = pos;
			}
			#if !(target.unicode)
			// ensure utf8 chars are not cut
			else if (c >= 0x80) {
				pos++;
				if (c >= 0xFC)
					pos += 4;
				else if (c >= 0xF8)
					pos += 3;
				else if (c >= 0xF0)
					pos += 2;
				else if (c >= 0xE0)
					pos++;
			}
			#end
		else if (StringTools.isEof(c))
			throw "Unclosed string";
		}
		#if target.unicode
		if (prev != -1)
			cancelSurrogate();
		#end
		if (buf == null) {
			return str.substr(start, pos - start - 1);
		} else {
			buf.addSub(str, start, pos - start - 1);
			return buf.toString();
		}
	}

	inline function parseNumber(c:Int):Dynamic {
		var start = pos - 1;
		var minus = c == '-'.code, digit = !minus, zero = c == '0'.code;
		var point = false, e = false, pm = false, end = false;
		while (true) {
			c = nextChar();
			switch (c) {
				case '0'.code:
					if (zero && !point)
						invalidNumber(start);
					if (minus) {
						minus = false;
						zero = true;
					}
					digit = true;
				case '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code, '8'.code, '9'.code:
					if (zero && !point)
						invalidNumber(start);
					if (minus)
						minus = false;
					digit = true;
					zero = false;
				case '.'.code:
					if (minus || point || e)
						invalidNumber(start);
					digit = false;
					point = true;
				case 'e'.code, 'E'.code:
					if (minus || zero || e)
						invalidNumber(start);
					digit = false;
					e = true;
				case '+'.code, '-'.code:
					if (!e || pm)
						invalidNumber(start);
					digit = false;
					pm = true;
				default:
					if (!digit)
						invalidNumber(start);
					pos--;
					end = true;
			}
			if (end)
				break;
		}

		var f = Std.parseFloat(str.substr(start, pos - start));
		if(point) {
			return f;
		} else {
			var i = Std.int(f);
			return if (i == f) i else f;
		}
	}

	inline function nextChar() {
		return StringTools.fastCodeAt(str, pos++);
	}

	inline function nextCharNonWS() {
		var r;
		do
		{
			r = StringTools.fastCodeAt(str, pos++);
		} while( r == ' '.code || r == '\r'.code || r == '\n'.code || r == '\t'.code );

		return r;
	}

	inline function eatWS() {
		var r;
		do
		{
			r = StringTools.fastCodeAt(str, pos++);
		} while( r == ' '.code || r == '\r'.code || r == '\n'.code || r == '\t'.code );
		pos--;
	}

	function invalidChar() {
		pos--; // rewind
		throw 'Invalid char ${str.charAt(pos)} (${StringTools.fastCodeAt(str, pos)}) at position ${pos}';
	}

	function invalidNumber(start:Int) {
		throw "Invalid number at position " + start + ": " + str.substr(start, pos - start);
	}
}