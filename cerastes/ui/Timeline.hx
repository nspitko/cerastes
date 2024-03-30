package cerastes.ui;

import hxd.snd.Channel;
import h2d.Object;
import tweenxcore.Tools.Easing;


enum abstract OperationType(Int) from Int to Int {
	var None = 0;
	// Tweens
	var Linear = 100;
	var ExpoIn = 101;
	var ExpoOut = 102;
	var ExpoInOut = 103;

	// Events
	var AnimPlay = 200;
	var AnimPause = 201;
	var AnimSetFrame = 203;

	var SoundPlay = 210;
	var SoundStop = 211;

	public function toString()
	{
		return switch( this )
		{
			case None: "None";
			case Linear: "Linear";
			case ExpoIn: "Exponential In";
			case ExpoOut: "Exponential Out";
			case ExpoInOut: "Exponential In/Out";
			//
			case AnimPlay: "Play";
			case AnimPause: "Pause";
			case AnimSetFrame: "Set Frame";
			//
			case SoundPlay: "Play";
			case SoundStop: "Stop";

			default: "Unknown";
		}

	}

  //
}

enum abstract TargetType(Int) {
	var Object = 0;
	var Filter = 1;
}

/**
 * Instantly set a value to a new one
 */
@:structInit class TimelineOperation
{
	public var target: String = null; // The element we're going to change
	public var targetType: TargetType = Object; // What are we actually pointing to
	public var key: String = null; // Key to modify
	public var value: Dynamic = null; // Value to set
	public var initialValue: Dynamic = null; // For tweens, the start value.
	public var hasInitialValue: Bool = false; // To handle zero start values...
	public var intSnap: Bool = false; // Slam floats to nearest int? (Useful for x/y)
	public var frame: Int = 0;

	public var duration: Int = 0;
	public var type: OperationType = None;

	public var stepRate: Float = 0; // If > 0, step at this reduced speed

	public function clone( )
	{
		var cls = Type.getClass(this);
		var inst = Type.createEmptyInstance(cls);
		var fields = Type.getInstanceFields(cls);
		for (field in fields)
		{

			// generic copy
			var val:Dynamic = Reflect.field(this,field);
			if ( !Reflect.isFunction(val) )
			{
				Reflect.setField(inst,field,val);
			}

		}

		return inst;
	}

}

@:structInit class TimelineState
{
	public var startValue: Dynamic = null;
	public var stepTimer: Float = 0;
	public var targetHandle: Dynamic = null;
}

@:structInit class Timeline
{
	@serializeType("cerastes.timeline.TimelineOperation")
	public var operations: Array<TimelineOperation> = [];

	public var frames: Int = 100;
	public var frameRate: Int = 10;

	public var name: String = "Unnamed Timeline";

	public function clone( )
	{
		var cls = Type.getClass(this);
		var inst = Type.createEmptyInstance(cls);
		var fields = Type.getInstanceFields(cls);
		for (field in fields)
		{
			if( field == "operations" || field.length == 0) // Fixes a bug in HL when inheriting interfaces
			{
				continue;
			}
			else
			{
				// generic copy
				var val:Dynamic = Reflect.field(this,field);
				if ( !Reflect.isFunction(val) )
				{
					Reflect.setField(inst,field,val);
				}
			}
		}

		inst.operations = [];

		// Now clone children
		for( c in operations )
		{
			inst.operations.push( c.clone( ) );
		}
		return inst;
	}

}

class TimelineRunner implements Tickable
{

	var timeline: Timeline;
	var timelineState: Array<TimelineState> = [];

	@:noCompletion public var finished(get, null): Bool = false;

	function get_finished() { return finished; }

	public var playing: Bool = false;
	public var loop: Bool = false;
	public var removeOnComplete = false;

	inline function frameToTime( frame: Int ): Float { return frame / timeline.frameRate; }
	inline function timeToFrame( time: Float ): Int { return Math.floor( time * timeline.frameRate ); }

	@noSerialize var playingSounds: Array<Channel> = [];

	@noSerialize public var frame(get, never): Int;
	@noSerialize public var time: Float = 0;
	@noSerialize public var ui: h2d.Object = null;

	@noSerialize public var onComplete: Void -> Void = null;

	function get_frame() { return timeToFrame(time); }

	public function new( t: Timeline, u: Object )
	{
		ui = u;
		timeline = t;

		// Sort ops
		timeline.operations.sort((a, b) -> { return a.frame - b.frame; });
		ensureState();
	}

	public function play()
	{
		time = 0;
		playing = true;
		finished = false;

		// 3/13/24 @spitko This is a bug factory so I wanted to remove it but
		// it's still an issue.
		//
		// Hack: Immediately play first frame so we can set out initial state
		// (else we might go visible for one frame in the wrong state)
		tick(0);
	}

	function ensureState()
	{
		if( timeline.operations.length != timelineState.length )
		{
			timelineState = [];
			for( i in 0 ... timeline.operations.length )
			{
				var op = timeline.operations[i];
				var state: TimelineState = {};
				var target = ui.getObjectByName(op.target);

				if( op.hasInitialValue )
					state.startValue = op.initialValue != null ? op.initialValue : 0;
				//else
				//	state.startValue = Reflect.getProperty( target, op.key );

				state.targetHandle = switch( op.targetType )
				{
					case Filter: target.filter;
					default: target;
				}

				timelineState.push(state);
			}
		}
	}


	public function stop()
	{
		playing = false;

		if( playingSounds == null )
			return;

		for( s in playingSounds )
			s.stop();

		playingSounds = [];

	}

	public function pause()
	{
		playing = false;


		for( s in playingSounds )
			s.pause = true;


	}

	public function resume()
	{
		playing = true;
		for( s in playingSounds )
			s.pause = false;
	}

	#if hlimgui

	public function setFrame( f: Int, shouldPlay: Bool = false )
	{

		if( shouldPlay )
			play();

		if( f == frame )
			return;

		finished = false;

		var t = frameToTime( f );
		if( t < time )
		{
			time = -1;
		}
		else
		{
			// Force re-simulate the last two frames just to be sure we're in a good state.
			//time = time -2;
		}

		// Clear out handles since we probably screwed with the scene in the editor.
		for( i in  0 ... timeline.operations.length )
		{
			if( i >= timelineState.length )
				timelineState.push({});
			timelineState[i].targetHandle = null;
		}

		playing = true;
		finished = false;
		var ticks = 0;
		while( frame < f  )
		{
			tick( 1 / timeline.frameRate );
			ticks++;
			if( ticks > 1000 )
			{
				Utils.warning('Runaway animation!! t=$time f=$f frame=$frame');
				stop();
				break;
			}
		}


		if( !shouldPlay )
			stop();
	}

	function setTime( t: Float )
	{
		var wasPlaying = playing;
		var wasFinished = finished;

		playing = true;
		finished = false;

		time = 0;

		// Revert state
		var idx = timeline.operations.length-1;
		while( idx >= 0 )
		{
			var op = timeline.operations[idx];
			var state = timelineState[idx];
			if( op.key != null && state.targetHandle != null )
			{
				Reflect.setProperty(state.targetHandle, op.key, state.startValue);
			}
			idx--;
		}

		ensureState();
		tick(t);

		playing = wasPlaying;
		finished = wasFinished;

		if( !playing )
			pause();


	}

	#end

	public function tick(d: Float )
	{
		if( !playing || finished )
			return;

		var tLast = time;
		time += d;

		// Jacky hack to make sure looping is smooth
		var m = loop ? timeline.frames - 1: timeline.frames;

		if( frame > m  )
		{
			if( onComplete != null )
				onComplete();

			onComplete = null;

			if( loop )
			{
				time -= timeline.frames * (1/timeline.frameRate);
			}
			else if( removeOnComplete )
			{
				finished = true;
			}
			else
			{
				//Utils.info('frame=${frame}@t=${time} from delta=${d} (max=${m}), pausing!!');
				playing = false;
			}

			return;
		}


		for( i in 0 ... timeline.operations.length )
		{
			var op = timeline.operations[i];
			var state = timelineState[i];

			var start = frameToTime(op.frame);
			var adjTime = time - start;
			var adjLastTime = tLast - start;

			// Fixup saveload drama
			if( op.value == null )
				op.value = 0;

			var duration = op.duration / timeline.frameRate;

			var firstFrame = adjTime >= 0 && ( adjLastTime < 0 || tLast == 0 );
			var lastFrame = adjTime >= duration && adjLastTime < duration;

			var active = ( adjTime > 0 && adjTime <= duration ) || firstFrame || lastFrame;
			if( !active )
				continue;

			if( op.target == null )
				continue;

			var target = state.targetHandle;

			var changed: Bool = false;

			switch( op.type )
			{
				case None #if js | null #end:
					if( op.key == null )
						continue;

					Reflect.setProperty(target, op.key, op.value);
					changed = true;

				case AnimPlay:
					var anim = Std.downcast(target, h2d.Anim );
 					if( anim != null )
					{
						anim.currentFrame = 0;
						anim.pause = false;
					}

				case AnimPause:
					var anim = Std.downcast(target, h2d.Anim );
					if( anim != null )
						anim.pause = true;

				case AnimSetFrame:
					var anim = Std.downcast(target, h2d.Anim );
					if( anim != null )
						anim.currentFrame = op.value;

				case SoundPlay:
					// HACK: A hack to work around the earlier tick(0) hack causing audio to play
					// multiple times if triggered on frame 0. :pain:
					if( d == 0 )
						continue;

					var sound = Std.downcast(target, cerastes.ui.Sound );
					if( sound != null )
					{
						var channel = sound.play();
						if( adjTime > 0.1)
						{
							channel.position = adjTime;
						}
						if( playingSounds == null )
							playingSounds = [];
						playingSounds.push(channel);
					}

				case SoundStop:
					var sound = Std.downcast(target, cerastes.ui.Sound );
					if( sound != null )
						sound.stop();



				case Linear | ExpoIn | ExpoOut | ExpoInOut:
					if( op.key == null )
						continue;

					if( !Utils.verify( duration > 0, 'Tween Operation has invalid duration ${op.duration}, defaulting to 1' ))
						duration = 1 * timeline.frameRate;

					if( ( firstFrame && state.startValue == null ))
					{
						// EnsureState already filled it out if we had a specified initial
						//if( op.hasInitialValue )
						//	state.startValue = op.initialValue != null ? op.initialValue : 0;
						//else
						state.startValue = Reflect.getProperty( target, op.key );
					}

					if( lastFrame )
					{
						Reflect.setProperty(target, op.key, op.value);
						changed = true;
					}
					else
					{
						if( op.stepRate > 0 )
						{
							state.stepTimer += d;

							if( !firstFrame )
							{

								if( state.stepTimer < op.stepRate )
									continue;

								state.stepTimer -= op.stepRate;
							}
						}

						var tweenFunc = switch( op.type )
						{
							case Linear: Easing.linear;
							case ExpoIn: Easing.expoIn;
							case ExpoOut: Easing.expoOut;
							case ExpoInOut: Easing.expoInOut;
							default: Easing.linear; // Fallback
						}

						var f = tweenFunc( adjTime / duration );
						var v = ( f * ( op.value - state.startValue ) ) + state.startValue;

						if( op.intSnap )
							v = Math.round(v);

						Reflect.setProperty(target, op.key, v);
						changed = true;
					}

				default:
					Utils.warning('Unhandled timeline event ${op.type}');

			}

			// Hacks.
			if( changed )
			{
				switch( op.targetType )
				{
					case Object:
						switch( op.key )
						{
							case "x" | "y" | "scaleX" | "scaleY" | "rotation":
								// setters
								var target: h2d.Object = state.targetHandle;
								@:privateAccess target.posChanged = true;

								// @todo: perf? Not sure we need to change this every frame for some of these cases.
								// onContentChanged();
								if( @:privateAccess target.parentContainer != null )
									@:privateAccess target.parentContainer.contentChanged(target);

							case "visible":
								var target: h2d.Object = state.targetHandle;
								// onContentChanged();
								if( @:privateAccess target.parentContainer != null )
									@:privateAccess target.parentContainer.contentChanged(target);
							default:
						}
					default:
				}
			}


		}
	}
}