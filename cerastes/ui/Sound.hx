package cerastes.ui;

import cerastes.fmt.CUIResource;
import h2d.Object;

@:keep
class Sound extends h2d.Object
{
	public var cue: String;

	var handle: hxd.res.Sound;

	public function new( ?parent: Object )
	{
		super(parent);
	}

	public function play( )
	{
		#if hlwwise
		// For now: Stop any existing instances.
		// this is only used for timeline stuff right now
		// expand later if needed. I know it's annoying
		// now that there are dependences but ~tehe
		var evt = wwise.Api.Event.make('Stop_${cue}');
		wwise.Api.postEvent(evt);

		var evt = wwise.Api.Event.make('Play_${cue}');
		wwise.Api.postEvent(evt);
		#else
		handle = hxd.Res.loader.load(cue).toSound();
		handle.play();
		#end
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