package cerastes;
import cerastes.file.CDParser;
import haxe.Json;
import cerastes.Utils.*;


abstract LocalizedString(String) from String
{
	inline public function new(i:String)  {
		this = i;
	}

	inline public function get(...rest: String)
	{
		var str = LocalizationManager.localize(this);

		return LocalizationManager.formatStr(str, rest.toArray());
	}

	@:to
	public inline function toStringg(): String
	{
		return LocalizationManager.localize(this);
	}
}


@:structInit
class LocalizationFile
{
	public var version: Int = 1;
	public var tokens: Map<String, String>;

	@noSerialize
	public var dirty: Bool = false;
	@noSerialize
	public var file: String = null;

#if tools
	public function save()
	{
		if( !dirty )
			return;

		sys.io.File.saveContent('res/${file}', cerastes.file.CDPrinter.print( this ) );

		dirty = false;
	}

#end
}

class LocalizationManager
{
	public static var replacements = new Map<String,String>();
	public static var contexts = new Map<String, LocalizationFile>();
	public static var language: String;

	public static var tokenRegex = ~/#([A-z0-9]+)__/;

	public static function initialize( language: String )
	{
		//LocalizationManager.language = language;
		//var rows: Array<JsonLocalizationFile> = Json.parse( hxd.Res.load("data/localization.json").toText() );
		//Utils.assert( rows != null && rows.length > 0, "Failed to parse localization file!" );

		// Always load the common context.
		loadFile('data/localization_${language}.loc', "common");


	}

	#if tools

	public function setKey(token: String, value: String)
	{
		var context = getContext(token);
		var c = contexts[context];

		if( Utils.assert( c != null, "Failed to set localization key; context not loaded!!" ) )
			return;

		c.tokens[token] = value;
	}

	#end

	public static function loadFile( file: String, context: String )
	{
		var loc: LocalizationFile = CDParser.parse( hxd.Res.loader.load( file ).entry.getText(), LocalizationFile );
		loc.file = file;

		contexts.set(context, loc);

	}

	// Clears all contexts other than common. Useful to call this between major barriers to free up ram.
	public static function clearContexts()
	{
		for( context => loc in contexts )
		{
			if( context != "common" )
				contexts.remove(context);
		}

	}

	static function getContext(token: String )
	{
		var context = "common";
		if( tokenRegex.match( token ) )
		{
			context = tokenRegex.matched(1);
			if( context == null || !contexts.exists(context) )
			{
				return "";
			}
		}
		return context;
	}

	public static function localize(token: String, ...rest: String) : String
	{
		if( Utils.assert( token != null, "Tried to localized null string as token!" ) )
			return "null";

		var context = getContext(token);

		// Tokens may specify a context. If so, the format is #context__token
		// else we assume the context is "common"

		var str = contexts[context].tokens[token];

		if( str == null )
		{
			Utils.warning('Token $token is missing for language $language');
			str = token;
		}

		return formatStr(str, rest.toArray());
	}

	public static function formatStr(str: String, ?subs: Array<String>)
	{
		// @todo what was this doing???
		//str = ~/^[\t ]+|[\t ]+$/gm.replace( str, "");

		if( subs != null )
		{
			for( i in 0...subs.length )
			{
				str = StringTools.replace(str,"%"+(i+1),subs[i]);

			}
		}


		for( key in LocalizationManager.replacements.keys() )
		{
			var replace = LocalizationManager.replacements[key];
			str = StringTools.replace(str,"$"+key,replace);

		}

		return str;
	}

	#if hlimgui

	public static function writeToken( token: String, context: String, value: String )
	{

	}
	#end
}