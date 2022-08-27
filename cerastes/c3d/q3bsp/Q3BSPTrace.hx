package cerastes.c3d.q3bsp;

import cerastes.c3d.q3bsp.BSPFile.BSPTextureDef;
import cerastes.c3d.q3bsp.BSPFile.BSPBrushSideDef;
import cerastes.c3d.q3bsp.BSPFile.BSPFileDef;
import cerastes.c3d.q3bsp.BSPMap.BSPPatchDef;
import cerastes.c3d.q3bsp.BSPFile.BSPBrushDef;
import cerastes.c3d.q3bsp.BSPFile.BSPLeafDef;
import cerastes.c3d.q3bsp.BSPFile.BSPPlaneDef;
import h3d.Vector;

typedef BSPTraceResult = {
	var allSolid: Bool;
	var startSolid: Bool;
	var fraction: Float;
	var endPos: Vector;
	var plane: DPlane_t;
	var ?surfaceFlags: Int;
	var ?contents: Int;
	var ?entityNum: Int;
}

enum TraceType {
	RAY;
	SPHERE;
	BOX;
}

// CM_trace.c
typedef Trace_t = {
	var allSolid: Bool;
	var startSolid: Bool;
	var fraction: Float;
	var endPos: Vector;
	var plane: BSPPlaneDef;
	var ?surfaceFlags: Int;
	var ?contents: Int;
	var ?entityNum: Int;
}

typedef Sphere_t = {
	var use: Bool;
	var ?radius: Float;
	var ?halfHeight: Float;
	var ?offset: Vector;
}

typedef TraceWork_t = {
	var start: Vector;
	var end: Vector;
	var size: haxe.ds.Vector<Vector>; 			// Size of the box being swept through the model
	var offsets: haxe.ds.Vector<Vector>; 		// [signbits][x] = either size[0][x] or size[1][x]
	var maxOffset: Float;  						// longest corner length from origin
	var extents: Vector; 						// greatest of abs(size[0]) and abs(size[1])
	var bounds: haxe.ds.Vector<Vector>; 		// enclosing box of start and end surrounding by size
	var modelOrigin: Vector; 					// Origin of the model tracing through
	var contents: Int;							// ored contents of the model tracing through
	var isPoint: Bool;							// optimized case
	var trace: Trace_t;							// returned from trace call
	var sphere: Sphere_t;
}

typedef Brush_t = {
	var shaderNum: Int;
	var contents: Int;
	//var bounds: haxe.ds.Vector<Vector>;
	var numSides: Int;
}

class BSPTrace
{
	public static var bsp: BSPFileDef;

	// Helper function to create a TraceWork_t
	static function createTraceWork() : TraceWork_t
	{
		return {
			start: new Vector(),
			end: new Vector(),
			size: haxe.ds.Vector.fromData([
				new Vector(),
				new Vector()
			]),
			offsets: haxe.ds.Vector.fromData([
				new Vector(),
				new Vector(),
				new Vector(),
				new Vector(),
				new Vector(),
				new Vector(),
				new Vector(),
				new Vector()
			]),
			maxOffset: 0,
			extents: new Vector(),
			bounds: haxe.ds.Vector.fromData([
				new Vector(),
				new Vector()
			]),
			modelOrigin: new Vector(),
			contents: 0,
			isPoint: false,
			trace: {
				allSolid: false,
				startSolid: false,
				fraction: -1,
				endPos: new Vector(),
				plane: null,
				surfaceFlags: 0,
				contents: 0,
				entityNum: 0
			},
			sphere: {
				use: false
			}
		}
	}

	static function getBrush( brushNum: Int ) : Brush_t
	{
		var bd: BSPBrushDef = bsp.brushes[ brushNum ];
		var t: BSPTextureDef = bsp.textures[ bd.texture ];

		return {
			shaderNum: bd.texture,
			contents: t.contents,
			//bounds: bd.,
			numSides: bd.numBrushSides
		}
	}


	static function traceThroughLeaf( tw: TraceWork_t, leaf: BSPLeafDef )
	{
		//var k: Int;
		var brushNum: Int;
		var b: Brush_t;
		var patch: BSPPatchDef;

		for( k in 0 ... leaf.numLeafBrushes )
		{
			brushNum = bsp.leafBrushes[ leaf.leafBrush + k ];

			b = getBrush( brushNum );


			// @todo checkcount optimization

			if( ( b.contents & tw.contents ) == 0 ) // @bugbug inverted???
				continue;

			traceThroughBrush( tw, b );
			if( tw.trace.fraction == 0 )
				return;
		}

		for( k in 0 ... leaf.numLeafFaces )
		{
			//patch = bsp.
		}
	}

	static function traceThroughBrush( tw: TraceWork_t, b: Brush_t )
	{

	}


}