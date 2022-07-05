package cerastes.c3d.anim;

import h3d.anim.Animation;

/**
 * Mask commposer blends two composers, using a mask to filter joints from the blending op
 */

class MaskElement extends ComposerElement
{
	public function init( animA: Animation, animB: Animation, time: Float )
	{
		this.time = time;
		
		Utils.assert( animA.isInstance && animB.isInstance, "Both input animations must be instances" );
		for( o in anim1.objects.copy() )
			if( objectsMap.get(o.objectName) )
				anim1.unbind(o.objectName);
		for( o in anim2.objects.copy() )
			if( !objectsMap.get(o.objectName) )
				anim2.unbind(o.objectName);
	}
}
