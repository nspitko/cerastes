package cerastes.c3d.map;
import h3d.col.Point;
import h3d.Vector4;
import hxd.snd.Data.SampleFormat;
import h3d.mat.PbrMaterial.PbrStencilCompare;
import hxd.fs.FileEntry;
import cerastes.c3d.map.Data;

enum ParseScope {
    PS_FILE;
    PS_COMMENT;
    PS_ENTITY;
    PS_PROPERTY_VALUE;
    PS_BRUSH;
    PS_PLANE_0;
    PS_PLANE_1;
    PS_PLANE_2;
    PS_TEXTURE;
    PS_U;
    PS_V;
    PS_VALVE_U;
    PS_VALVE_V;
    PS_ROT;
    PS_U_SCALE;
    PS_V_SCALE;
}

class MapParser
{
	var scope: ParseScope = PS_FILE;
	var comment = false;
	var entityIdx = -1;
	var brushIdx = -1;
	var faceIdx = -1;
	var componentIdx = -1;
	var currentProperty: StringBuf = null;
	var valveUVs = false;

	var parseError = false;

	var currentFace: Face = {};
	var currentBrush: Brush = {};
	var currentEntity: Entity = {};

	var mapData: MapData;

	public function new() {}

	// ----------------------------------------------------------------------------
	function resetMapData()
	{
		mapData = {};
	}

	// ----------------------------------------------------------------------------
	function resetCurrentFace()
	{
		currentFace = {};
	}

	// ----------------------------------------------------------------------------
	function resetCurrentBrush()
	{
		currentBrush = {};
	}

	// ----------------------------------------------------------------------------
	function resetCurrentEntity()
	{
		currentEntity = {};
	}

	// ----------------------------------------------------------------------------
	public function load( file: FileEntry ) : MapData
	{
		resetMapData();
		resetCurrentFace();
		resetCurrentBrush();
		resetCurrentEntity();

		scope = PS_FILE;
		comment = false;
		entityIdx = -1;
		brushIdx = -1;
		faceIdx = -1;
		componentIdx = 0;
		valveUVs = false;

		if( file == null )
			return null;

		var mapBytes = file.getBytes();

		var cur = 0;
		var c: Int;
		var buff = haxe.io.Bytes.alloc( 1024 );
		var buffHead = 0;

		parseError = false;

		while( cur < mapBytes.length )
		{
			c = mapBytes.get(cur++);
			if( c == '\n'.code )
			{
				buff.set(buffHead, 0);
				token(buff);
				newline();
				buffHead = 0;
			}
			else if( isSpace(c) )
			{
				buff.set(buffHead, 0);
				token(buff);
				buffHead = 0;
			}
			else
			{
				buff.set(buffHead++, c);
			}
		}

		if( parseError )
			return null;

		return mapData;
	}

	// ----------------------------------------------------------------------------
	function setScope( newScope: ParseScope )
	{
		//trace('New scope: ${newScope}');
		scope = newScope;
	}

	// ----------------------------------------------------------------------------
	inline function stringsMatch( a: String, b: String ): Bool
	{
		return a == b;
	}


	// ----------------------------------------------------------------------------
	function token( buff: haxe.io.Bytes )
	{
		//trace( 'token: ${buff.toString()}');
		var str = buff.toString();

		var prop: Property;

		if( comment )
		{
			return;
		}
		else if( StringTools.startsWith(str, '//') )
		{
			comment = true;
			return;
		}

		switch( scope )
		{
			case PS_FILE:
				if( str == "{" )
				{
					entityIdx++;
					brushIdx = -1;
					setScope(PS_ENTITY);
				}

			case PS_ENTITY:
				if( buff.get(0) == '"'.code )
				{
					prop = {};
					currentEntity.properties.push(prop);
					prop.key = str.substr(1, str.length -2 );
					setScope(PS_PROPERTY_VALUE);
				}
				else if( buff.get(0) == '{'.code )
				{
					brushIdx++;
					faceIdx = -1;
					setScope(PS_BRUSH);
				}
				else if( buff.get(0) == '}'.code )
				{
					commitEntity();
					setScope( PS_FILE );
				}

			case PS_PROPERTY_VALUE:
				prop = currentEntity.properties[ currentEntity.properties.length-1 ];

				var isFirst = buff.get(0) == '"'.code;
				var isLast = buff.get(str.length-1) == '"'.code;

				if( isFirst )
				{
					currentProperty = new StringBuf();
				}

				if( isFirst || isLast )
				{
					currentProperty.add( str );
				}
				else
				{
					currentProperty.add( ' ${str} ' );
				}

				if( isLast )
				{
					var val = currentProperty.toString();
					prop.value = val.substring(1, val.length - 1);
					//trace('prop: ${prop.key} -> ${prop.value}');
					setScope(PS_ENTITY);
				}

			case PS_BRUSH:
				if( str == "(")
				{
					faceIdx++;
					componentIdx = 0;
					setScope(PS_PLANE_0);
				}
				else if ( str == "}")
				{
					commitBrush();
					setScope(PS_ENTITY);
				}
			case PS_PLANE_0:
				if( str == ")")
				{
					componentIdx = 0;
					setScope(PS_PLANE_1);
				}
				else
				{
					switch( componentIdx )
					{
						case 0: currentFace.planePoints.v0.x = Std.parseFloat( str );
						case 1: currentFace.planePoints.v0.y = Std.parseFloat( str );
						case 2: currentFace.planePoints.v0.z = Std.parseFloat( str );
					}
					componentIdx++;
				}
			case PS_PLANE_1:
				if( str == ")")
				{
					componentIdx = 0;
					setScope(PS_PLANE_2);
				}
				else if( str != "(")
				{
					switch( componentIdx )
					{
						case 0: currentFace.planePoints.v1.x = Std.parseFloat( str );
						case 1: currentFace.planePoints.v1.y = Std.parseFloat( str );
						case 2: currentFace.planePoints.v1.z = Std.parseFloat( str );
					}
					componentIdx++;
				}

			case PS_PLANE_2:
				if( str == ")")
				{
					setScope(PS_TEXTURE);
				}
				else if( str != "(")
				{
					switch( componentIdx )
					{
						case 0: currentFace.planePoints.v2.x = Std.parseFloat( str );
						case 1: currentFace.planePoints.v2.y = Std.parseFloat( str );
						case 2: currentFace.planePoints.v2.z = Std.parseFloat( str );
					}
					componentIdx++;
				}

			case PS_TEXTURE:
				currentFace.textureIdx = mapData.registerTexture(str);
				setScope(PS_U);

			case PS_U:
				if( str == "[")
				{
					valveUVs = true;
					componentIdx = 0;
					setScope( PS_VALVE_U );
				}
				else
				{
					valveUVs = false;
					currentFace.uvStandard.u = Std.parseFloat( str );
					setScope( PS_V );
				}

			case PS_V:
				currentFace.uvStandard.v = Std.parseFloat( str );
				setScope( PS_ROT );

			case PS_VALVE_U:
				parseError = true;
				Utils.error("STUB :: Valve UVs");

			case PS_VALVE_V:
				parseError = true;
				Utils.error("STUB :: Valve UVs");

			case PS_ROT:
				currentFace.uvExtra.rot = Std.parseFloat( str );
				setScope( PS_U_SCALE );

			case PS_U_SCALE:
				currentFace.uvExtra.scaleX = Std.parseFloat( str );
				setScope( PS_V_SCALE );

			case PS_V_SCALE:
				currentFace.uvExtra.scaleY = Std.parseFloat( str );
				commitFace( );
				setScope(PS_BRUSH);

			case PS_COMMENT:

		}

	}

	// ----------------------------------------------------------------------------
	function newline()
	{
		if( comment ) comment = false;
	}

	// ----------------------------------------------------------------------------
	inline function isSpace(code: Int)
	{
		return code == ' '.code || code == '\t'.code || code == '\r'.code;
	}

	// ----------------------------------------------------------------------------
	function commitEntity()
	{
		currentEntity.spawnType = EST_ENTITY;
		currentEntity.index = mapData.entities.length;
		mapData.entities.push( currentEntity );
		resetCurrentEntity();
	}

	// ----------------------------------------------------------------------------
	function commitBrush()
	{
		currentEntity.brushes.push( currentBrush );

		resetCurrentBrush();

	}

	function commitFace( )
	{
		var v0v1: Point = currentFace.planePoints.v1.sub( currentFace.planePoints.v0 );
		var v1v2: Point = currentFace.planePoints.v2.sub( currentFace.planePoints.v1 );

		currentFace.planeNormal = v1v2.cross( v0v1 ).normalized();
		currentFace.planeDist = currentFace.planeNormal.dot( currentFace.planePoints.v0 );
		currentFace.isValveUV = valveUVs;

		currentBrush.faces.push( currentFace );

		resetCurrentFace();
	}
}