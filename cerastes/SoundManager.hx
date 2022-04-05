package cerastes;

import hxd.snd.SoundGroup;
import hxd.snd.ChannelGroup;
import cerastes.file.CDParser;
import hxd.snd.Manager;
import hxd.res.Sound;
import hxd.res.Resource;
import h3d.scene.Object;
import h3d.prim.Primitive;
import hxd.snd.Channel;

import tweenxcore.Tools.Easing;

@:enum abstract SoundCueKind(Int) from Int to Int {
	var CueGlobal = 0; // Event does not have spatial data
	var Cue2D = 1; // Event exists in a 2d world with spatial data
	var Cue3D = 2; // Event exists in a 3d world with spatial data
}

@:enum abstract SoundCueItemType(Int) from Int to Int {
	var Clip = 0; // A sound clip
	var Event = 1; // A sound event

}

@:structInit
class SoundCueItem
{
	public var name: String = null; // Expresses either a file or event name depending on type
	public var type: SoundCueItemType = Clip;
	public var start: Float = 0;
	public var end: Float = 0; // If zero, use clip length
	public var loop: Bool = false; // Loop this cue

	public var volume: Float = 0;
	public var volumeVariance: Float = 0; // If set, choose a random volume between volume and volume + volumeVariance

	public var pitch: Float = 0; // if zero, use default pitch, else float where 1.0 = default
	public var pitchVariance: Float = 0; // If set, choose a random pitch between pitch and pitch + pitchVariance

	public var lowpass: Float = 0; // if zero, use default pitch, else float where 1.0 = default
	public var lowpassVariance: Float = 0; // If set, choose a random pitch between pitch and pitch + pitchVariance


}

@:structInit
class SoundCueTrack
{
	@serializeType("cerastes.SoundCueItem")
	public var items: Array<SoundCueItem> = null;
}

@:structInit
class SoundCue
{
	public var type: SoundCueKind = CueGlobal;
	@serializeType("cerastes.SoundCueTrack")
	public var tracks: Array<SoundCueTrack> = null;

	@noSerialize
	public var x: Float = 0;
	@noSerialize
	public var y: Float = 0;
	@noSerialize
	public var z: Float = 0;

	public function play( ?channelGroup: ChannelGroup = null, ?soundGroup = null )
	{
		var instance = new CueInstance( this, channelGroup, soundGroup );
		SoundManager.instances.add(instance);

		return instance;
	}
}

@:structInit
class SoundCueFile
{
	public var version: Int = 1;
	@serializeType("cerastes.SoundCue")
	public var cues: Map<String, SoundCue> = null; // Name is dot mapped to folders, ie 'Foo.Bar.Baz' is clip 'Baz' in 'foo/bar'
}

class CueInstance
{
	var cue: SoundCue;
	public var time(default, null): Float;
	var channelGroup: ChannelGroup;
	var soundGroup: SoundGroup;


	public var isFinished = false;

	public var activeChannels = new haxe.ds.List<hxd.snd.Channel>();


	public function new( cue: SoundCue, channelGroup: ChannelGroup = null, soundGroup: SoundGroup = null )
	{
		this.cue = cue;
		this.soundGroup = soundGroup == null ? new SoundGroup( null ) : soundGroup;
		this.channelGroup = channelGroup;
	}

	public function tick( delta: Float )
	{
		if( cue == null ) return;

		var lastTime = time;
		time += delta;
		isFinished = true;
		for( track in cue.tracks )
		{
			for( item in track.items )
			{
				if( item.start >= lastTime && item.start < time )
				{
					switch( item.type )
					{
						#if js
						case Clip | null:
						#else
						case Clip:
						#end
							var channel = hxd.Res.loader.loadCache( item.name, Sound ).play(item.loop, 1.0, channelGroup, soundGroup );
							if( item.pitch > 0 || item.pitchVariance > 0 )
							{
								var effect = new hxd.snd.effect.Pitch( ( item.pitch > 0 ? item.pitch : 1 ) + Math.random() * item.pitchVariance );
								channel.addEffect( effect );
							}

							if( item.lowpass > 0 || item.lowpassVariance > 0 )
							{
								var effect = new hxd.snd.effect.LowPass();
								effect.gainHF = ( item.lowpass > 0 ? item.lowpass : 1 ) + Math.random() * item.lowpassVariance ;
								channel.addEffect( effect );
							}


							if( item.volume > 0 || item.volumeVariance > 0 )
							{
								channel.volume = ( item.volume > 0 ? item.volume : 1 ) + Math.random() * item.volumeVariance;
							}
							activeChannels.add( channel );

						case Event:
							var instance = SoundManager.play( item.name, channelGroup, soundGroup );
					}

				}
				else if( item.start > time )
					isFinished = false;
			}
		}

		// Check to see if we have any active channels
		if( isFinished )
		{
			for( c in activeChannels )
				if( c.duration > c.position )
					isFinished = false;
		}
	}

	public function stop()
	{
		for( channel in activeChannels )
		{
			channel.stop();
		}
		cue = null;
		isFinished = true;
	}
}

@:allow(cerastes.SoundCue)
class SoundManager
{
	private static var cues: Map<String,SoundCue> = [];
	private static var instances: haxe.ds.List<CueInstance> = new haxe.ds.List<CueInstance>();

	public static function loadFile( file: String )
	{
		var fileContents = hxd.Res.loader.load(file).toText();
		var f: SoundCueFile = CDParser.parse(  fileContents, SoundCueFile);
		for( name => cue in f.cues )
			cues.set(name, cue);
	}

	public static function play( cueName: String, ?channelGroup: ChannelGroup = null, ?soundGroup = null )
	{
		var cue = cues.get(cueName );
		if( Utils.assert( cue != null, 'Tried to play unknown cue ${cueName}') )
			return null;

		var instance = new CueInstance( cue, channelGroup, soundGroup );
		instances.add(instance);

		return instance;


	}


	static function init()
	{

	}

	public static function tick( delta: Float )
	{

		for( i in instances )
		{
			i.tick( delta );
			if( i.isFinished )
				instances.remove(i);
		}
	}





}