package cerastes.ui;

import cerastes.fmt.CUIResource;
import h2d.Object;

@:keep
class Sound extends h2d.Object
{
	public var cue: String;

	var handle: hxd.res.Sound;
	public var volume: Float = 1;
	public var loop: Bool = false;

	public function new( ?parent: Object )
	{
		super(parent);
	}

	public function play( )
	{
		if( handle == null )
		{
			var path = cue;
			if( !hxd.Res.loader.exists(path ) )
			{
				path = 'sfx/${cue}.ogg';
				if( !hxd.Res.loader.exists(path ) )
				{
					path = 'audio/${cue}.ogg';
					if( !hxd.Res.loader.exists(path ) )
					{
						Utils.error('Failed to resolve an asset path for cue ${cue}');
						return null;
					}
				}
			}
			handle = hxd.Res.loader.load(path).toSound();
		}
		handle.stop();
		return handle.play(loop, volume);
	}

	public function stop( )
	{
		#if hlwwise
		var evt = wwise.Api.Event.make('Stop_${cue}');
		wwise.Api.postEvent(evt);
		#else
		if( handle != null )
		{
			handle.stop();
			handle = null;
		}
		#end
	}
}