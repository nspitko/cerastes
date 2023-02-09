package cerastes.ui;

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
	public var frame: Int = 0;

	public var duration: Int = 0;
	public var type: OperationType = None;

	public var stepRate: Float = 0; // If > 0, step at this reduced speed

	@noSerialize public var startValue: Dynamic = null; // If not null, specifies the value we start from. If null, use current value.
	@noSerialize public var stepTimer: Float = 0;
	@noSerialize public var targetHandle: Dynamic = null;

}

@:structInit class Timeline
{
	@serializeType("cerastes.timeline.TimelineOperation")
	public var operations: Array<TimelineOperation> = [];

	public var frames: Int = 100;
	public var frameRate: Int = 10;

	inline function frameToTime( frame: Int ): Float { return frame / frameRate; }
	inline function timeToFrame( time: Float ): Int { return Math.floor( time * frameRate ); }

	#if hlimgui
	public var name: String = "Unnamed Timeline";
	#end

	@noSerialize public var frame(get, never): Int;
	@noSerialize public var time: Float = -1;
	@noSerialize public var ui: h2d.Object = null;

	function get_frame() { return timeToFrame(time); }

	public function setFrame( f: Int )
	{
		var t = frameToTime( f );
		if( t < time )
		{
			time = -1;
		}
		else
		{
			// Force re-simulate the last two frames just to be sure we're in a good state.
			time = time -2;
		}

		// Clear out handles since we probably screwed with the scene in the editor.
		for( o in operations )
			o.targetHandle = null;

		while( frame < f  )
		{
			tick( 1/frameRate );
		}
	}

	public function tick(d: Float )
	{
		var tLast = time;
		time += d;

		var lastFrame = frame;

		for( op in operations )
		{
			var start = frameToTime(op.frame);
			var adjTime = time - start;
			var adjLastTime = tLast - start;

			// Fixup saveload drama
			if( op.value == null )
				op.value = 0;

			var duration = op.duration / frameRate;

			var firstFrame = adjTime >= 0 && adjLastTime < 0;
			var lastFrame = adjTime >= duration && adjLastTime < duration;

			var active = ( adjTime > 0 && adjTime <= duration ) || firstFrame || lastFrame;
			if( !active )
				continue;

			if( op.target == null )
				continue;

			if( op.targetHandle == null )
			{
				var targetName = op.target;

				var target = ui.getObjectByName(targetName);
				if( Utils.assert(target != null, 'Timeline target ${op.target} is missing') )
				{
					op.target = null;
					continue;
				}

				op.targetHandle = switch( op.targetType )
				{
					case Filter: target.filter;
					default: target;
				}
			}


			var target = op.targetHandle;

			var changed: Bool = false;

			switch( op.type )
			{
				case None:
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


				case Linear | ExpoIn | ExpoOut | ExpoInOut:
					if( op.key == null )
						continue;

					if( Utils.assert( duration > 0, 'Tween Operation has invalid duration ${op.duration}, defaulting to 1' ))
						duration = 1 * frameRate;

					if( firstFrame && op.startValue == null )
					{
						if( op.initialValue != null )
							op.startValue = op.initialValue;
						else
							op.startValue = Reflect.getProperty( target, op.key );
					}

					if( lastFrame )
					{
						Reflect.setProperty(target, op.key, op.value);
						trace(op.value);
						changed = true;
					}
					else
					{
						if( op.stepRate > 0 )
						{
							op.stepTimer += d;

							if( op.stepTimer < op.stepRate )
								continue;

							op.stepTimer -= op.stepRate;
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
						var v = ( f * ( op.value - op.startValue ) ) + op.startValue;

						Reflect.setProperty(target, op.key, v);
						//trace(v);
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
								@:privateAccess target.posChanged = true;
							default:
						}
					default:
				}
			}


		}

	}
}