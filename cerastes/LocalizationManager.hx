package cerastes;
import cerastes.Utils.*;

typedef LocFile = {
	var names: Array<String>;
	var rooms: Array<String>;
	var strings: Array<String>;
}

class LocalizationManager
{
	public static var instance(default, null):LocalizationManager = new LocalizationManager();


	public var replacements = new Map<String,String>();

	var initialized = false;

	public function new()
	{
		replacements.set("foo", "bar");

	}

	public function initialize()
	{
		if( initialized )
			return;



		initialized = true;

	}

	public static function localize(str: String, ?subs: Array<String>)
	{
		//var str = ~/^[\t ]+|[\t ]+$/gm.replace( key, "");

		return formatStr(str, subs);
	}

	public static function formatStr(str: String, ?subs: Array<String>)
	{
		str = ~/^[\t ]+|[\t ]+$/gm.replace( str, "");

		if( subs != null )
		{
			for( i in 0...subs.length )
			{
				str = StringTools.replace(str,"%"+(i+1)+"$s",subs[i]);

			}
		}


		for( key in LocalizationManager.instance.replacements.keys() )
		{
			var replace = LocalizationManager.instance.replacements[key];
			str = StringTools.replace(str,"$"+key,replace);

		}

		return str;
	}
}