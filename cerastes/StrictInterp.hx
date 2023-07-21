package cerastes;

import hscript.Interp;

@:keep enum InterpVariableType
{
	IVTInt;
	IVTFloat;
	IVTBool;
	IVTString;
}

@:structInit class InterpVariable
{
	public var name: String;
	public var type: InterpVariableType;
	public var comment: String;
}


class StrictInterp extends Interp
{
	override function setVar( name : String, v : Dynamic ) {
		if( !variables.exists( name ) )
			error( EUnknownVariable( name ) );

		variables.set(name, v);
	}
}