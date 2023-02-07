package cerastes.ui;

import tweenxcore.Tools.Easing;


@:enum
abstract OperationType(Int) {
  var None = 0;
  // Tweens
  var Linear = 100;
  var ExpoIn = 101;
  var ExpoOut = 102;
  var ExpoInOut = 103;

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
	public var key: String = null; // Key to modify
	public var value: Dynamic = null; // Value to set
	public var start: Float = 0;

	public var duration: Float = 0;
	public var type: OperationType = None;
	public var startValue: Dynamic = null; // If not null, specifies the value we start from. If null, use current value.

	public var stepRate: Float = 0; // If > 0, step at this reduced speed
	@:noSerialize public var stepTimer: Float = 0;
	@:noSerialize public var targetHandle: Dynamic = null;
	@:noSerialize public var targetType: TargetType = Object;


}

class Timeline
{
	public var operations: Array<TimelineOperation> = [];
	public var time: Float;
	public var ui: h2d.Object;

	public function new( ui: h2d.Object, it: Array<TimelineOperation> )
	{
		operations = it;
		this.ui = ui;
	}

	public function tick(d: Float )
	{
		var tLast = time;
		time += d;

		for( op in operations )
		{
			var adjTime = time - op.start;
			var adjLastTime = tLast - op.start;

			var firstFrame = adjTime >= 0 && adjLastTime < 0;
			var lastFrame = adjTime >= op.duration && adjLastTime < op.duration;

			var active = ( adjTime > 0 && adjTime <= op.duration ) || firstFrame || lastFrame;
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

			switch( op.type )
			{
				case None:
					Reflect.setProperty(target, op.key, op.value);

				default:
					if( Utils.assert( op.duration > 0, 'Tween Operation has invalid duration ${op.duration}, defaulting to 0.1' ))
						op.duration = 0.1;

					if( firstFrame && op.startValue == null )
					{
						op.startValue = Reflect.field( target, op.key );
					}

					if( lastFrame )
					{
						Reflect.setProperty(target, op.key, op.value);
						continue;
					}

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

					var f = tweenFunc( adjTime / op.duration );
					var v = ( f * ( op.value - op.startValue ) ) + op.startValue;

					Reflect.setProperty(target, op.key, v);

					// Hacks.
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