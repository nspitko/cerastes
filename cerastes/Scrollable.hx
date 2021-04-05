package cerastes;

import h2d.Interactive;
import h2d.Text;
import h2d.Object;
import h2d.Mask;
import cerastes.Utils.*;
import tweenxcore.Tools.Easing;

class Scrollable extends Mask
{
	var top: Float = 0;
	var lastHeight: Float = 0;
	public var childContainer : Object;
	var scrollSpeed = 80;

	var canWheelScroll = true;
	var autoResetHeight = true;

	var currentTween :Tween = null;

	public var scrollHandle : Interactive;

	var dragChange = 0.;
	var dragging = false;
	

	public function new( width: Int, height: Int, ?parent: Object)
	{
		super( width, height, parent);

		scrollHandle = new Interactive(200,1200,this);

		scrollHandle.propagateEvents = true;

		scrollHandle.onPush  = function(e){
			dragging = true;
			
		}
		scrollHandle.onRelease  = function(e){
			dragging = false;
			
		}

		

		childContainer = new Object(this);
		
	}

	public function tick( delta: Float )
	{
		if( autoResetHeight && lastHeight != childContainer.getBounds().height - height )
		{
			top = 0;
			childContainer.y = 0;
			lastHeight = childContainer.getBounds().height - height;

			if( lastHeight > 0 )
				scrollHandle.visible = true;

			else scrollHandle.visible = false;
		}

		scrollHandle.y = ( top / ( childContainer.getBounds().height - height ) ) * ( height - scrollHandle.getBounds().height );
		scrollHandle.x = this.width - scrollHandle.getBounds().width;
	}

	override function onAdd() {
		super.onAdd();
		var scene = getScene();
		scene.addEventListener(onEvent);
	}

	public function onEvent( e : hxd.Event ) 
	{
		if( canWheelScroll )
		{
			switch( e.kind ) 
			{
				case EWheel:
					top += e.wheelDelta * scrollSpeed;
					var max = ( childContainer.getBounds().height - height ) ;
					top = clamp( top, 0, max > 0 ? max : 0 ) ;
					
					updateScrollPosition();
				default:

				case EMove:
					if( dragging )
					{
						
						
						top = ( ( e.relY - this.y ) / height ) * ( childContainer.getBounds().height - height );
						
						updateScrollPosition();
					}
			}
		}
	}

	function updateScrollPosition()
	{
		var min = -(childContainer.getBounds().height - height);
		childContainer.y = clamp( -top ,min < 0 ? min : 0, 0);
		top = -childContainer.y;
	}

	function scrollTo(val:Float)
	{
		if( currentTween != null )
		{
			currentTween.abort();
		}

		var max = ( childContainer.getBounds().height - height ) ;
		val = clamp( val, 0, max > 0 ? max : 0 );
		currentTween = new Tween(0.5,childContainer.y, -val,function(v){
			childContainer.y = v;
		}, Easing.expoInOut);
	}

	function scrollToBotton()
	{
		scrollTo( ( childContainer.getBounds().height - height ) );
	}

}