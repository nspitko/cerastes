package cerastes.ui;

import h2d.Object;
import tweenxcore.Tools.Easing;


@:enum
abstract OperationType(Int) from Int to Int {
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

@:enum
abstract TargetType(Int) {
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
	public var frame: Int = 0;

	public var duration: Int = 0;
	public var type: OperationType = None;

	public var stepRate: Float = 0; // If > 0, step at this reduced speed



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

}

class TimelineRunner
{

	var timeline: Timeline;
	var timelineState: Array<TimelineState> = [];

	public var finished: Bool = false;

	public var playing: Bool = false;
	public var loop: Bool = false;


	inline function frameToTime( frame: Int ): Float { return frame / timeline.frameRate; }
	inline function timeToFrame( time: Float ): Int { return Math.floor( time * timeline.frameRate ); }



	#if hlimgui
	@noSerialize var playingSounds: Array<Sound> = [];
	#end

	@noSerialize public var frame(get, never): Int;
	@noSerialize public var time: Float = 0;
	@noSerialize public var ui: h2d.Object = null;

	@noSerialize public var onComplete: Void -> Void = null;

	function get_frame() { return timeToFrame(time); }

	public function new( t: Timeline, u: Object )
	{
		ui = u;
		timeline = t;
		for( i in 0 ... t.operations.length )
			timelineState.push({});
	}

	public function play()
	{
		time = 0;
		playing = true;

		// Hack: Immediately play first frame so we can set out initial state
		// (else we might go visible for one frame in the wrong state)
		tick(0);
	}


	public function stop()
	{
		playing = false;

		#if hlimgui
		if( playingSounds == null )
			return;

		for( s in playingSounds )
			s.stop();

		playingSounds = [];
		#end
	}

	public function pause()
	{
		playing = !playing;
	}

	#if hlimgui

	public function setFrame( f: Int )
	{
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
		while( frame < f  )
		{
			tick( 1 / timeline.frameRate );
		}

		stop();
	}

	#end

	public function tick(d: Float )
	{
		if( !playing || finished )
			return;

		var tLast = time;
		time += d;

		var lastFrame = frame;

		if( frame > timeline.frames  )
		{
			if( onComplete != null )
				onComplete();

			onComplete = null;

			if( loop )
			{
				time = 0;
			}
			else
			{
				finished = true;
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

			if( state.targetHandle == null )
			{
				var targetName = op.target;

				var target = ui.getObjectByName(targetName);
				if( Utils.assert(target != null, 'Timeline target ${op.target} is missing') )
				{
					op.target = null;
					continue;
				}

				state.targetHandle = switch( op.targetType )
				{
					case Filter: target.filter;
					default: target;
				}
			}


			var target = state.targetHandle;

			var changed: Bool = false;

			switch( op.type )
			{
				case None:
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
					var sound = Std.downcast(target, cerastes.ui.Sound );
					if( sound != null )
					{
						sound.play();
						#if hlimgui
						if( playingSounds == null )
							playingSounds = [];
						playingSounds.push(sound);
						#end
					}

				case SoundStop:
					var sound = Std.downcast(target, cerastes.ui.Sound );
					if( sound != null )
						sound.stop();



				case Linear | ExpoIn | ExpoOut | ExpoInOut:
					if( op.key == null )
						continue;

					if( Utils.assert( duration > 0, 'Tween Operation has invalid duration ${op.duration}, defaulting to 1' ))
						duration = 1 * timeline.frameRate;

					if( firstFrame && state.startValue == null )
					{
						if( op.hasInitialValue )
							state.startValue = op.initialValue != null ? op.initialValue : 0;
						else
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