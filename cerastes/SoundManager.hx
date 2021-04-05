package cerastes;

import h3d.scene.Object;
import h3d.prim.Primitive;
import hxd.snd.Channel;
import db.Data;
import tweenxcore.Tools.Easing;

class SoundManager
{
	private static var channels = new Map<String,Channel>();

	private static var music : Channel;
	public static var musicVolume( default, set ): Float = 1.;
	public static var soundVolume: Float = 1.;

	public static var currentMusicFile = "";

	static function set_musicVolume(v)
	{
		musicVolume = v;
		if( music != null )
			music.volume = v;

		return v;
	}

	public static function dsfx( o: Object, id: String )
	{
		//var d = o.getAbsPos().getPosition().distance( GameState.player.getAbsPos().getPosition() );

		sfx(id);

	}


	public static function sfx( id: String, ?vol: Float = 1, ?loop: Bool = false )
	{
		var channel: Channel;
		if( channels.exists( id ) )
		{
			channel = channels[id];
			channel.stop();
			channel.sound.stop();
			channel.sound.play(loop);
			channel.volume = vol;
			return;
		}


		var res = null;
		try
		{
			res = 	hxd.Res.load( "sfx/" + id + ".mp3" );
		}
		catch(e : Dynamic )
		{
			try
				{
					res = 	hxd.Res.load( "sfx/" + id + ".wav" );
				}
				catch(e : Dynamic )
				{
					Utils.warning('Missing sfx: sfx/${id}');
					return;
				}
		}

		if( res == null )
		{
			Utils.error('Missing sound file: ' +  id);
			return;
		}


		try {
			var snd;
			snd = res.toSound();

			var channel = snd.play( loop );
			channel.priority = 0.5;

			channel.volume = vol == 1 ? soundVolume : vol;

			channels.set(id,channel);
		}
		catch( e: Dynamic )
		{
			Utils.error('Unable to play $id: $e');
			return;
		}


	}

	public static function stopsfx( id: String )
	{
		var channel: Channel;
		if( channels.exists( id ) )
		{
			channel = channels[id];
			channel.stop();

		}

	}

	public static function stopall(  )
	{
		for( id => channel in channels )
		{
			channel.sound.stop();
			channel.stop();


		}

	}

	public static function play( id: String )
	{
		/*
		var cue = Data.sounds.resolve( id, true );
		if( cue == null )
		{
			Utils.error('Missing sound cue: $id');
			return;
		}

		if( channels.exists( id ) )
		{
			switch( cue.overlap )
			{
				case cut:
					channels[id].stop();
				case ignore:
					return;
				case overlap:
			}
		}

		// @todo support play modes
		var idx = Std.random( cue.sounds.length );

		var res = 	hxd.Res.load( cue.sounds[idx].sound );

		if( res == null )
		{
			Utils.error('Missing sound file: ' +  cue.sounds[idx]);
			return;
		}

		var snd = res.toSound();
		var channel = snd.play( cue.loop );
		channel.priority = 0.5;

		if( cue.priority != null )
			channel.priority = cue.priority;

		if( cue.volume != null )
			channel.volume = cue.volume;

		channels.set(id,channel);

		channel.onEnd = function() {
			channels.remove(id);
		};
		*/

	}

	public static function stopMusic( ?speed: Float )
	{
		if( speed == null ) speed = 2;
		if( music != null )
		{
			var oldMusic = music;
			new Tween(speed, musicVolume, 0, function(v){
				oldMusic.volume = v;
			},
			Easing.expoOut,
			function(){ oldMusic.stop(); }
			);
		}

		currentMusicFile = "";

	}

	public static function playMusic( cue: String )
	{
		// Intentionally making this shit so I come up with something better later

		if( cue == null || cue.length == 0 )
		{
			stopMusic();
			return;
		}

		if( cue == currentMusicFile )
			return;

		currentMusicFile = cue;

		if( music != null )
		{
			var oldMusic = music;
			new Tween(2, musicVolume, 0, function(v){
				oldMusic.volume = v;
			},
			Easing.expoOut,
			function(){ oldMusic.stop(); }
			);
		}

		var crossFade = music != null;

		music = hxd.Res.loader.load( "mus/" + cue ).toSound().play(true);

		music.priority = 1.;

		if( crossFade )
		{
			new Tween(2, 0, musicVolume, function(v){
				music.volume = v;
			},
			Easing.expoIn
			);
		}
		else
			music.volume = musicVolume;

	}


}