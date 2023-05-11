package cerastes;

import hscript.Interp;

class StrictInterp extends Interp
{
	override function setVar( name : String, v : Dynamic ) {
		if( !variables.exists( name ) )
			error( EUnknownVariable( name ) );
		
		variables.set(name, v);
	}
}