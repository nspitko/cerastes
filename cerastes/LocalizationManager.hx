package cerastes;
#if hlimgui
import cerastes.tools.ImguiTool.ImGuiPopupType;
import cerastes.tools.ImguiTool.ImGuiToolManager;
#end
import game.GameState;
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
	public static var contexts = new Map<String, Map<String, String>>();
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

		Utils.error("Who calls me?");

		//c.tokens[token] = value;
	}

	#end

	public static function loadFile( file: String, context: String )
	{
		var res =  hxd.Res.loader.load( file );
		var loc: LocalizationFile = CDParser.parse( res.entry.getText(), LocalizationFile );
		loc.file = file;

		addToContext(context, loc);
		//contexts.set(context, loc);

		#if tools
		res.watch(() -> {
			try
			{
				var res =  hxd.Res.loader.load( file );
				var loc: LocalizationFile = CDParser.parse( res.entry.getText(), LocalizationFile );

				addToContext(context, loc);

				#if hlimgui
				ImGuiToolManager.showPopup('Live Reload','Successfully reloaded ${res.name}.', ImGuiPopupType.Info);
				#end
			}
			catch( e )
			{
				Utils.warning('Live reload of ${res.name} failed!');
			}
		});
		#end

	}

	static function addToContext(context: String, loc: LocalizationFile)
	{
		if( !contexts.exists(context) )
			contexts.set(context, []);

		var ctx = contexts[context];
		for( k => v in loc.tokens )
		{
			ctx.set(k, v);
		}
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

	public static function setDynamicToken(token: String, value: String )
	{
		contexts["common"].set(token, value);
	}

	public static function localize(token: String, ...rest: String) : String
	{
		if( Utils.assert( token != null, "Tried to localized null string as token!" ) )
			return "null";

		var context = getContext(token);

		// Tokens may specify a context. If so, the format is #context__token
		// else we assume the context is "common"

		var str: String = contexts[context][token];

		if( str == null )
		{
			Utils.warning('Token $token is missing for language $language');
			str = token;
		}

		return formatStr(str, rest.toArray());
	}

	public static function exists( token: String )
	{
		var context = getContext(token);
		return contexts[context].exists( token );
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