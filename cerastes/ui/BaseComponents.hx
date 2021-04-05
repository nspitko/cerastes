package cerastes.ui;

typedef TransitionSettings = {
	duration: Float,
	func: String,
}


class Flow extends h2d.Flow 
{
	public var transitionProperties = new Map<String, TransitionSettings>();
}