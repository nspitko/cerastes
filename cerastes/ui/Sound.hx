package cerastes.ui;

import cerastes.SoundManager.CueInstance;
import cerastes.fmt.CUIResource;
import h2d.Object;

enum CueChannel {
	SFX;
	Music;
}

@:keep
class Sound extends h2d.Object
{
	public var cue: String;

	var handle: CueInstance;
	public var volume: Float = 1;
	public var loop: Bool = false;
	public var channel: CueChannel = SFX;

	public function new( ?parent: Object )
	{
		super(parent);
	}

	public function play( )
	{
		handle = SoundManager.play( cue, channel == Music ? SoundManager.musicChannelGroup : SoundManager.sfxChannelGroup );
		handle.channel.volume = volume;
		handle.channel.loop = loop;
		return handle.channel;
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