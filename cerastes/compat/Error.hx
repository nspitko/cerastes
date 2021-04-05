package cerastes.compat;
import cerastes.Utils.*;

class Error
{
	public function new( msg: String )
	{
		trace("ERROR: " + msg);
		if( BREAK_ON_ASSERT )
		{
			#if hl 
				hl.Api.breakPoint();
			#end
		}
	} 
}