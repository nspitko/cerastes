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
		return LocalizationManager.formatStr(this, rest.toArray());
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
}

class LocalizationManager
{
	public static var replacements = new Map<String,String>();
	public static var tokens = new Map<String, String>();
	public static var language: String;

	public static function initialize( language: String )
	{
		//LocalizationManager.language = language;
		//var rows: Array<JsonLocalizationFile> = Json.parse( hxd.Res.load("data/localization.json").toText() );
		//Utils.assert( rows != null && rows.length > 0, "Failed to parse localization file!" );

		var loc: LocalizationFile = CDParser.parse( hxd.Res.data.localization_english.entry.getText(), LocalizationFile );

		tokens = loc.tokens;


	}

	public static function localize(token: String, ...rest: String) : String
	{
		//var str = ~/^[\t ]+|[\t ]+$/gm.replace( key, "");
		if( Utils.assert( token != null, "Tried to localized null string as token!" ) )
			return "null";

		return formatStr(token, rest.toArray());
	}

	public static function formatStr(token: String, ?subs: Array<String>)
	{
		var str = tokens.get(token);

		if( str == null )
		{
			Utils.warning('Token $token is missing for language $language');
			str = token;
		}

		str = ~/^[\t ]+|[\t ]+$/gm.replace( str, "");

		if( subs != null )
		{
			for( i in 0...subs.length )
			{
				str = StringTools.replace(str,"%"+(i+1)+"$s",subs[i]);

			}
		}


		for( key in LocalizationManager.replacements.keys() )
		{
			var replace = LocalizationManager.replacements[key];
			str = StringTools.replace(str,"$"+key,replace);

		}

		return str;
	}
}