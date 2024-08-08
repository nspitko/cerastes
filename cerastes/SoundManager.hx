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

enum abstract SoundCueKind(Int) from Int to Int {
	var CueGlobal = 0; // Event does not have spatial data
	var Cue2D = 1; // Event exists in a 2d world with spatial data
	var Cue3D = 2; // Event exists in a 3d world with spatial data
}

enum abstract SoundCueItemType(Int) from Int to Int {
	var Clip = 0; // A sound clip
	var Event = 1; // A sound event

}

@:structInit
class SoundCueItem
{
	public var name: String = null; // Expresses either a file or event name depending on type
	public var type: SoundCueItemType = Clip;
	//public var start: Float = 0;
	//public var end: Float = 0; // If zero, use clip length




}

@:structInit
class SoundCue
{
	public var type: SoundCueKind = CueGlobal;
	@serializeType("haxe.ds.StringMap")
	public var clips: Array<String> = null;

	public var loop: Bool = false; // Loop this cue

	public var volume: Float = 0;
	public var volumeVariance: Float = 0; // If set, choose a random volume between volume and volume + volumeVariance

	public var pitch: Float = 0; // if zero, use default pitch, else float where 1.0 = default
	public var pitchVariance: Float = 0; // If set, choose a random pitch between pitch and pitch + pitchVariance

	public var lowpass: Float = 0; // if zero, use default pitch, else float where 1.0 = default
	public var lowpassVariance: Float = 0; // If set, choose a random pitch between pitch and pitch + pitchVariance


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
	public var channelGroup: ChannelGroup;
	public var soundGroup: SoundGroup;

	public var channel: Channel;


	public function new( cue: SoundCue, channelGroup: ChannelGroup = null, soundGroup: SoundGroup = null )
	{
		this.cue = cue;
		this.soundGroup = soundGroup == null ? new SoundGroup( null ) : soundGroup;
		this.channelGroup = channelGroup;

		if( cue == null || cue.clips == null )
			return;

		var lastTime = time;

		var clipFile = cue.clips[ Std.random(cue.clips.length) ];
		if(clipFile == null )
			return;

		channel = hxd.Res.loader.loadCache( clipFile, Sound ).play(cue.loop, 1.0, channelGroup, soundGroup );
		if( cue.pitch > 0 || cue.pitchVariance > 0 )
		{
			var effect = new hxd.snd.effect.Pitch( ( cue.pitch > 0 ? cue.pitch : 1 ) + Math.random() * cue.pitchVariance );
			channel.addEffect( effect );
		}

		if( cue.lowpass > 0 || cue.lowpassVariance > 0 )
		{
			var effect = new hxd.snd.effect.LowPass();
			effect.gainHF = ( cue.lowpass > 0 ? cue.lowpass : 1 ) + Math.random() * cue.lowpassVariance ;
			channel.addEffect( effect );
		}


		if( cue.volume > 0 || cue.volumeVariance > 0 )
		{
			channel.volume = ( cue.volume > 0 ? cue.volume : 1 ) + Math.random() * cue.volumeVariance;
		}
	}

	public function stop()
	{
		channel.stop();
	}
}

@:allow(cerastes.SoundCue)
class SoundManager
{
	private static var cues: Map<String,SoundCue> = [];
	private static var instances: haxe.ds.List<CueInstance> = new haxe.ds.List<CueInstance>();

	public static var musicChannelGroup: ChannelGroup = new ChannelGroup("music");
	public static var sfxChannelGroup: ChannelGroup = new ChannelGroup("sfx");

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

		// Try to resolve a file of the same name

		if( cue == null )
		{
			var path = 'audio/${cueName}.ogg';
			if( !hxd.Res.loader.exists(path) )
			{
				path = 'audio/${cueName}.mp3';
				if( !hxd.Res.loader.exists(path) )
				{
					path = 'audio/${cueName}.wav';
				}

			}


			if( hxd.Res.loader.exists(path) )
			{
				cue = {
					clips: [
							path
					]
				};
			}
		}





		if( !Utils.verify( cue != null, 'Tried to play unknown cue ${cueName}') )
			return null;

		var instance = new CueInstance( cue, channelGroup, soundGroup );
		instances.add(instance);

		return instance;

	}

	public static function playFile( file: String )
	{
		var snd = hxd.Res.loader.load(file).toSound();
		if( !Utils.verify(snd != null, 'Cannot load sound $file') )
			return;

		snd.play();
	}

	static var musicSnd: Sound;
	static var currentMusicFile: String;
	static var musicVol: Float = 0.5;
	public static function playMusicFile( file: String )
	{
		if( file == currentMusicFile )
			return;

		currentMusicFile = file;

		if( musicSnd != null )
		{
			musicSnd.stop();
		}

		musicSnd = hxd.Res.loader.load(file).toSound();
		musicSnd.play(true, musicVol);

	}


	static function init()
	{

	}

	public static function tick( delta: Float )
	{
	}





}