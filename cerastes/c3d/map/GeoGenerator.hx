package cerastes.c3d.map;

import h3d.Vector;
import cerastes.c3d.map.Data.FaceVertex;
import h3d.Matrix;
import cerastes.c3d.map.Data.FaceUVExtra;
import cerastes.c3d.map.Data.VertexUV;
import cerastes.c3d.map.Data.Face;
import cerastes.c3d.map.Data.Brush;
import cerastes.c3d.map.Data.FaceGeometry;
import cerastes.c3d.map.Data.BrushGeometry;
import cerastes.c3d.map.Data.EntityGeometry;
import cerastes.c3d.map.Data.MapData;
import h3d.col.Point;

class GeoGenerator
{
	static final vUp = new Point(0,0,1);
	static final vRight = new Point(0,1,0);
	static final vForward = new Point(1,0,0);

	static final EPSILON = 0.00001;

	var smoothNormals = false;

	var windEntityIdx = 0;
	var windBrushIdx = 0;
	var windFaceIdx = 0;

	var windFaceCenter: Point = new Point();
	var windFaceBasis: Point = new Point();
	var windFaceNormal: Point = new Point();

	var data: MapData;

	public function new(){}



	inline function PointRotate( input: Point, axis: Point, angle: Float)
	{
		var mat = new Matrix();
		mat.initRotationAxis(axis.toVector(), angle);

		return input.transformed( mat );
	}

	inline function deg2rad(deg: Float ) { return deg * (Math.PI / 180);	}
	inline function rad2deg(deg: Float ) { return deg * (180 / Math.PI);	}


	public function run( d: MapData )
	{
		this.data = d;

		// Alloc
		data.entityGeo = new haxe.ds.Vector<EntityGeometry>(data.entities.length);
		for( e in 0 ... data.entityGeo.length )
		{
			var entity = data.entities[e];
			var entityGeo: EntityGeometry = {};
			data.entityGeo.set(e, entityGeo);

			entityGeo.brushes = new haxe.ds.Vector<BrushGeometry>(entity.brushes.length);

			for(b in 0 ... entity.brushes.length )
			{
				var brush = entity.brushes[b];
				var brushGeo: BrushGeometry = {};
				entityGeo.brushes.set(b, brushGeo);

				brushGeo.faces = new haxe.ds.Vector<FaceGeometry>(brush.faces.length);

				for( f in 0 ... brush.faces.length )
				{
					var face = brush.faces[f];
					var faceGeo: FaceGeometry = {};
					brushGeo.faces.set(f, faceGeo);
				}
			}
		}

		for( e in 0 ... data.entities.length )
		{
			var entity = data.entities[e];
			entity.center = new Point(0,0,0);
			for( b in 0 ... entity.brushes.length )
			{
				var brush = entity.brushes[b];
				var brushGeo = data.entityGeo[e].brushes[b];
				var vertexCount = 0;
				brush.center = new Point(0,0,0);

				generateBrushVertices(e, b);


				for( f in 0 ... brushGeo.faces.length )
				{
					var faceGeo = brushGeo.faces[f];
					//trace('face ${f} has ${faceGeo.vertices.length} vertices');
					for( v in 0 ... faceGeo.vertices.length )
					{
						//trace('$v: ${faceGeo.vertices[v].vertex} ${faceGeo.vertices[v].normal} ${faceGeo.vertices[v].tangent} ');
						brush.center = brush.center.add( faceGeo.vertices[v].vertex );
						vertexCount++;
					}

				}

				if( vertexCount > 0 )
				{
					brush.center = CMath.dividePoint(brush.center, vertexCount );
				}

				//trace('Brush ${b} center -> ${brush.center}');

				entity.center = entity.center.add( brush.center );

			}

			if( entity.brushes.length > 0 )
			{
				entity.center = CMath.dividePoint( entity.center, entity.brushes.length );
				//trace('Center -> ${entity.center}');
			}
		}

		// wind face vertices. Die a little more inside.
		for( e in 0 ... data.entities.length )
		{
			var entity = data.entities[e];
			var entityGeo = data.entityGeo[e];
			for( b in 0 ... entity.brushes.length )
			{
				var brush = entity.brushes[b];
				var brushGeo = entityGeo.brushes[b];

				for( f in  0 ... brush.faces.length )
				{
					var face = brush.faces[f];
					var faceGeo = brushGeo.faces[f];

					if( faceGeo.vertices.length < 3 )
						continue;

					windEntityIdx = e;
					windBrushIdx = b;
					windFaceIdx = f;

					windFaceBasis = faceGeo.vertices[1].vertex.sub( faceGeo.vertices[0].vertex );
					windFaceCenter = new Point();
					windFaceNormal = face.planeNormal;

					for( v in 0 ... faceGeo.vertices.length )
					{
						windFaceCenter = windFaceCenter.add( faceGeo.vertices[v].vertex );
					}

					windFaceCenter = CMath.dividePoint( windFaceCenter, faceGeo.vertices.length );

					faceGeo.vertices.sort( sortVerticesByWinding );
					windEntityIdx = 0;


				}
			}
		}

		// index face vertices: we're like almost done so it's cool right? ....right?
		for( e in 0 ... data.entities.length )
		{
			var entity = data.entities[e];
			var entityGeo = data.entityGeo[e];
			for( b in 0 ... entity.brushes.length )
			{
				var brush = entity.brushes[b];
				var brushGeo = entityGeo.brushes[b];

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
		}

	}

	function generateBrushVertices(entityIdx: Int, brushIdx: Int )
	{
		var entity = data.entities[entityIdx];
		var brush = entity.brushes[brushIdx];

		for( f0 in 0 ... brush.faces.length )
		{
			for( f1 in 0 ... brush.faces.length)
			{
				for( f2 in 0 ... brush.faces.length)
				{
					var vertex = new Point();
					if( intersectFaces( brush.faces[f0], brush.faces[f1], brush.faces[f2], vertex ) )
					{
						if( vertexInHull( brush.faces, vertex ) )
						{
							var face = data.entities[entityIdx].brushes[brushIdx].faces[f0];
							var faceGeo = data.entityGeo[entityIdx].brushes[brushIdx].faces[f0];

							var normal = new Point();

							var phongProp = entity.getProperty("_phong");
							var phong = phongProp == "1";

							if( phong )
							{
								var phongAngleProp = entity.getProperty("_phong_angle");
								if( phongAngleProp != null )
								{
									var threshold = Math.cos( ( Std.parseFloat( phongAngleProp ) + 0.01 ) * 0.0174533 );
									normal = brush.faces[f0].planeNormal;
									if( brush.faces[f0].planeNormal.dot( brush.faces[f1].planeNormal ) > threshold )
										normal = normal.add( brush.faces[f1].planeNormal );
									if( brush.faces[f0].planeNormal.dot( brush.faces[f2].planeNormal ) > threshold )
										normal = normal.add( brush.faces[f2].planeNormal );

									normal.normalize();
								}
								else
								{
									normal = brush.faces[f0].planeNormal.add( brush.faces[f1].planeNormal ).add( brush.faces[f2].planeNormal).normalized();
								}
							}
							else
							{
								normal = face.planeNormal;
							}

							// Texture shenanigans
							var tex = data.getTexture( face.textureIdx );
							var uv: VertexUV;
							if( face.isValveUV )
								uv = getValveUV( vertex, face, tex.width, tex.height );
							else
								uv = getStandardUV( vertex, face, tex.width, tex.height );

							var tangent: Point;
							if( face.isValveUV )
								tangent = getValveTangent(face);
							else
								tangent = getStandardTangent(face);

							var uniqueVertex = true;
							var duplicateIndex = -1;

							for( v in  0 ... faceGeo.vertices.length )
							{
								var compVertex = faceGeo.vertices[v].vertex;
								if( vertex.sub( compVertex ).lengthSq() < EPSILON )
								{
									uniqueVertex = false;
									duplicateIndex = v;
									trace("Culling dupe vert");
									break;
								}
							}

							if( uniqueVertex )
							{
								var faceVert: FaceVertex = {
									vertex: vertex,
									normal: normal,
									uv: uv,
									tangent: tangent
								};
								faceGeo.vertices.push(faceVert);
							}
							else if(phong)
							{
								faceGeo.vertices[duplicateIndex].normal = faceGeo.vertices[duplicateIndex].normal.add(normal);
							}
						}
					}
				}
			}
		}

		for( f in 0 ... brush.faces.length )
		{
			var faceGeo = data.entityGeo[entityIdx].brushes[brushIdx].faces[f];

			for( v in 0 ... faceGeo.vertices.length )
			{
				faceGeo.vertices[v].normal.normalize();
			}
		}
	}

	function sign( v: Float ): Float
	{
		if( v > 0 )
			return 1.0;
		else if ( v < 0 )
			return -1.0;
		return 0;
	}

	function getValveTangent( face: Face )
	{
		Utils.error("STUB");

		return null;
	}

	function getValveUV( vertex: Point, face: Face, width: Int, height: Int  )
	{
		Utils.error("STUB");

		return null;
	}

	function getStandardTangent( face: Face) : Point
	{
		var tangentOut: Point = new Point();

		var du = face.planeNormal.dot( vUp );
		var dr = face.planeNormal.dot( vRight );
		var df = face.planeNormal.dot( vForward );

		var dua = Math.abs( du );
		var dra = Math.abs( dr );
		var dfa = Math.abs( df );

		var uAxis: Point = new Point();
		var vSign: Float = 0;
		if( dua >= dra && dua >= dfa )
		{
			uAxis = vForward;
			vSign = sign(du);
		}
		else if ( dra >= dua && dra >= dfa )
		{
			uAxis = vForward;
			vSign = -sign(dr);
		}
		else if( dfa >= dua && dfa >= dra )
		{
			uAxis = vRight;
			vSign = sign(df);
		}

		vSign *= sign( face.uvExtra.scaleY );
		uAxis = uAxis.multiply(vSign);
		uAxis = PointRotate( uAxis, face.planeNormal, -face.uvExtra.rot * vSign );

		tangentOut.x = uAxis.x;
		tangentOut.y = uAxis.y;
		tangentOut.z = uAxis.z;

		return tangentOut;
	}

	function getStandardUV( vertex: Point, face: Face, width: Int, height: Int )
	{
		var uvOut: VertexUV = {};

		var du = Math.abs( face.planeNormal.dot( vUp ) );
		var dr = Math.abs( face.planeNormal.dot( vRight ) );
		var df = Math.abs( face.planeNormal.dot( vForward ) );

		if( du >= dr && du >= df )
			uvOut = { u: vertex.x, v: -vertex.y };
		else if( dr >= du && dr >= df)
			uvOut = { u: vertex.x, v: -vertex.z};
		else if( df >= du && df >= dr )
			uvOut = { u: vertex.y, v: -vertex.z };

		var rotated: VertexUV = {};
		var angle = deg2rad( face.uvExtra.rot );
		rotated.u = uvOut.u * Math.cos(angle) - uvOut.v * Math.sin(angle);
		rotated.v = uvOut.u * Math.sin(angle) + uvOut.v * Math.cos(angle);

		uvOut = rotated;

		uvOut.u /= width;
		uvOut.v /= height;

		uvOut.u /= face.uvExtra.scaleX;
		uvOut.v /= face.uvExtra.scaleY;

		uvOut.u += face.uvStandard.u / width;
		uvOut.v += face.uvStandard.v / height;

		return uvOut;
	}

	function intersectFaces( f0: Face, f1: Face, f2: Face, out: Point)
	{
		var normal0 = f0.planeNormal;
		var normal1 = f1.planeNormal;
		var normal2 = f2.planeNormal;

		var denom = normal0.cross(normal1).dot(normal2);

		if( denom < EPSILON )
			return false;

		if( out != null )
		{
			// @bugbug verify!! https://github.com/QodotPlugin/libmap/blob/master/src/c/geo_generator.c#L336
			var cd0 = normal1.cross(normal2).multiply( f0.planeDist);
			var cd1 = normal2.cross(normal0).multiply( f1.planeDist);
			var cd2 = normal0.cross(normal1).multiply( f2.planeDist);

			// @todo this could be more efficient probably?
			var sum: Point = cd0.add(cd1.add(cd2));
			var result = CMath.dividePoint(sum, denom);

			out.set( result.x, result.y, result.z );
		}

		return true;
	}

	function vertexInHull( faces: Array<Face>, out: Point )
	{
		for( f in 0 ... faces.length )
		{
			var face = faces[f];
			var proj = face.planeNormal.dot(out);

			if( proj > face.planeDist && Math.abs( face.planeDist - proj ) > EPSILON )
				return false;
		}

		return true;
	}

	function sortVerticesByWinding( lhsV: FaceVertex, rhsV: FaceVertex )
	{
		var lhs = lhsV.vertex;
		var rhs = rhsV.vertex;

		var face = data.entities[windEntityIdx].brushes[windBrushIdx].faces[windFaceIdx];
		var faceGeo = data.entityGeo[windEntityIdx].brushes[windBrushIdx].faces[windFaceIdx];

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
}