package cerastes.c3d.bsp;

import cerastes.c3d.bsp.BSPFile.DBrush_t;
import h3d.col.Point;
import cerastes.c3d.bsp.BSPFile.DBrushSide_t;
import cerastes.c3d.bsp.BSPFile.BSPFileDef;

@:structInit class CollisionFace
{
	public var vertices: Array<Point> = [];
	public var indices: haxe.ds.Vector<Int> = null;
}

@:structInit class CollisionBrush
{
	// Face -> vertices
	public var faces: Array<CollisionFace> = [];
}

class BSPCollision
{
	var brushInfo: Array<CollisionBrush> = [];

	var bsp: BSPFileDef;

	var windEntityIdx = 0;
	var windBrushIdx = 0;
	var windFaceIdx = 0;

	var windFaceCenter: Point = new Point();
	var windFaceBasis: Point = new Point();
	var windFaceNormal: Point = new Point();

	public function new() {}

	public function createCollision(filedef: BSPFileDef )
	{
		bsp = filedef;
		brushInfo.resize( bsp.brushes.length);
		// Build vertex list
		for( brushIdx in 0 ... bsp.brushes.length )
		{
			var brush = bsp.brushes[brushIdx];

			var cbrush: CollisionBrush = {};
			brushInfo[brushIdx] = cbrush;

			cbrush.faces.resize( brush.numSides );
			for( i in 0 ... brush.numSides )
			{
				cbrush.faces[i] = {};
			}


			for( f0 in 0 ... brush.numSides)
			{
				for( f1 in 0 ... brush.numSides)
				{
					for( f2 in 0 ... brush.numSides)
					{
						var vertex = new Point();
						if( intersectSides( bsp.brushSides[ brush.firstSide + f0 ], bsp.brushSides[ brush.firstSide + f1 ], bsp.brushSides[ brush.firstSide + f2 ], vertex ) )
						{
							if( vertexInHull( brush, vertex ) )
							{
								var face = cbrush.faces[f0];
								var uniqueVertex = true;
								for( v in  0 ... face.vertices.length )
								{
									var compVertex = face.vertices[v];
									if( vertex.sub( compVertex ).lengthSq() < CMath.QEPSILON )
									{
										uniqueVertex = false;
										//duplicateIndex = v;
										//trace("Culling dupe vert");
										break;
									}
								}

								if( uniqueVertex )
									face.vertices.push(vertex);
							}
						}
					}
				}
			}



			//trace(verts);
		}



		// wind face vertices. Die a little more inside.
		for( b in 0 ... bsp.brushes.length )
		{

			var brush = bsp.brushes[b];
			var brushInfo = brushInfo[b];

			for( f in  0 ... brush.numSides )
			{
				var faceGeo = brushInfo.faces[f];
				var face = bsp.planes[ bsp.brushSides[brush.firstSide + f].planeNum ];

				if( faceGeo.vertices.length < 3 )
					continue;

				//windEntityIdx = e;
				windBrushIdx = b;
				windFaceIdx = f;

				var planeNormal = new Point( face.normal[0], face.normal[1], face.normal[2] );

				windFaceBasis = faceGeo.vertices[1].sub( faceGeo.vertices[0] );
				windFaceCenter = new Point();
				windFaceNormal = planeNormal;

				for( v in 0 ... faceGeo.vertices.length )
				{
					windFaceCenter = windFaceCenter.add( faceGeo.vertices[v] );
				}

				windFaceCenter = CMath.dividePoint( windFaceCenter, faceGeo.vertices.length );

				faceGeo.vertices.sort( sortVerticesByWinding );
				//windEntityIdx = 0;


			}

		}

		// index face vertices: we're like almost done so it's cool right? ....right?

		for( b in 0 ... bsp.brushes.length )
		{
			var brush = bsp.brushes[b];
			var brushGeo = brushInfo[b];

			for( f in  0 ... brushGeo.faces.length )
			{
				var faceGeo = brushGeo.faces[f];

				if( faceGeo.vertices.length < 3 )
					continue;

				faceGeo.indices = new haxe.ds.Vector<Int>( ( faceGeo.vertices.length - 2 ) * 3 );
				for( i in  0 ... faceGeo.vertices.length - 2 )
				{
					var idx = i*3;
					faceGeo.indices[idx + 0] = 0;
					faceGeo.indices[idx + 1] = i + 1;
					faceGeo.indices[idx + 2] = i + 2;
				}

				if( faceGeo.indices.length < 3)
					trace(' !! Brush $b Face $f has ${faceGeo.indices.length} indices');

			}
		}


		//debugDrawCollision();


	}

	function intersectSides( f0: DBrushSide_t, f1: DBrushSide_t, f2: DBrushSide_t, out: Point)
	{
		var n0 = bsp.planes[ f0.planeNum ].normal;
		var n1 = bsp.planes[ f1.planeNum ].normal;
		var n2 = bsp.planes[ f2.planeNum ].normal;

		var normal0 = new Point(n0[0], n0[1], n0[2]);
		var normal1 = new Point(n1[0], n1[1], n1[2]);
		var normal2 = new Point(n2[0], n2[1], n2[2]);

		var denom = normal0.cross(normal1).dot(normal2);

		if( denom < CMath.QEPSILON )
			return false;

		if( out != null )
		{
			var cd0 = normal1.cross(normal2).multiply( bsp.planes[ f0.planeNum ].dist );
			var cd1 = normal2.cross(normal0).multiply( bsp.planes[ f1.planeNum ].dist );
			var cd2 = normal0.cross(normal1).multiply( bsp.planes[ f2.planeNum ].dist );

			// @todo this could be more efficient probably?
			var sum: Point = cd0.add(cd1.add(cd2));
			var result = CMath.dividePoint(sum, denom);

			out.set( result.x, result.y, result.z );
		}

		return true;
	}

	function vertexInHull( brush: DBrush_t, out: Point )
	{
		for( i in 0 ... brush.numSides )
		{
			var face = bsp.brushSides[ brush.firstSide + i ];
			var plane = bsp.planes[face.planeNum];
			var norm = new Point(plane.normal[0], plane.normal[1], plane.normal[2]);
			var proj = norm.dot(out);

			if( proj > plane.dist && Math.abs( plane.dist - proj ) > CMath.QEPSILON )
				return false;
		}

		return true;
	}


	function sortVerticesByWinding( lhs: Point, rhs: Point )
	{
		var u = windFaceBasis.normalized();
		var v = u.cross(windFaceNormal).normalized();

		var localLhs = lhs.sub(windFaceCenter);
		var lhs_pu = localLhs.dot(u);
		var lhs_pv = localLhs.dot(v);

		var localRhs = rhs.sub(windFaceCenter);
		var rhs_pu = localRhs.dot(u);
		var rhs_pv = localRhs.dot(v);

		var lhsAngle = Math.atan2( lhs_pv, lhs_pu );
		var rhsAngle = Math.atan2( rhs_pv, rhs_pu );

		if( lhsAngle < rhsAngle )
			return -1;
		else if( lhsAngle > rhsAngle )
			return 1;

		return 0;
	}

	function debugDrawCollision()
	{
		var count = 0;
		for( i in 0 ... brushInfo.length )
		{
			var col = Std.random(0xFFFFFF);
			var iface = new bullet.Native.TriangleMesh();


			var bi = brushInfo[i];
			for( s in bi.faces )
			{
				if( s.indices == null || s.indices.length < 3)
					continue;

				var i = 0;
				while( i < s.indices.length )
				{
					var idx =  s.indices[i];
					var idxn =  s.indices[i+1];
					DebugDraw.line( s.vertices[idx], s.vertices[idxn], col, -1, 0.25 );
					i++;
					if( i % 3 == 2 ) i++;
				}
			}

			if( count++ > 100)
				return;



		}

		brushInfo = null;
	}
}