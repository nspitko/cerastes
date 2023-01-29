package cerastes.ui;

import h2d.Interactive;

class InteractiveContainer extends Interactive
{
	public override function onAdd()
	{
		super.onAdd();
		if( width == 0 && height == 0 )
		{
			var bounds = getBounds();
			width = bounds.width;
			height = bounds.height;
		}
	}
}