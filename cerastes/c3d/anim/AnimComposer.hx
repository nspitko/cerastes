package cerastes.c3d.anim;

/**
 * AnimComposer takes a stack of animation commands and tries to resolve a final pose out of it.
 *
 * It is designed to be graph driven, and accept an unbound number of sequences to blend. Each sequence
 * is actively driven by the graph that runs it, and rebuilt per-frame, so composer tries to avoid
 * allocation as much as possible, and relies on caching where possible.
 */

// ---------------------------------------------------------------------------

/**
 * Composer elements are graph driven blend elements. Elements last one frame and are
 * only used as drivers for the final pose. Any state needed to calculate the frame
 * is driven by the graph during creation, so they do not need to be aware of eg time.
 */
@:structInit
class ComposerElement
{
	var time: Float;
}

class AnimComposer
{

}