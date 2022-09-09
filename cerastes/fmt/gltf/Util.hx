package cerastes.fmt.gltf;

import cerastes.fmt.gltf.Data;
import cerastes.Utils as Debug;

class Util {

	// retrieve the float value from an accessor for a specified
	// entry (eg: vertex) and component (eg: x)
	public inline static function getFloat(data: Data, buffAcc:BuffAccess, entry:Int, comp:Int):Float {
		var buff = data.bufferData[buffAcc.bufferInd];
		Debug.assert(buffAcc.compSize == 4);
		var pos = buffAcc.offset + (entry * buffAcc.stride) + comp * 4;
		Debug.assert(pos < buffAcc.maxPos);
		return buff.getFloat(pos);
	}

	public static function getUShort(data: Data, buffAcc:BuffAccess, entry:Int, comp:Int):Int {
		var buff = data.bufferData[buffAcc.bufferInd];
		Debug.assert(buffAcc.compSize == 2);
		var pos = buffAcc.offset + (entry * buffAcc.stride) + comp * 2;
		Debug.assert(pos < buffAcc.maxPos);
		return buff.getUInt16(pos);
	}

	public static function getByte(data: Data, buffAcc:BuffAccess, entry:Int, comp:Int):Int {
		var buff = data.bufferData[buffAcc.bufferInd];
		Debug.assert(buffAcc.compSize == 1);
		var pos = buffAcc.offset + (entry * buffAcc.stride) + comp;
		Debug.assert(pos < buffAcc.maxPos);
		return buff.get(pos);
	}

	public static function getInt(data: Data, buffAcc:BuffAccess, entry:Int, comp:Int):Int {
		switch( buffAcc.compSize )
		{
			case 1:
				return getByte( data, buffAcc, entry, comp );
			case 2:
				return getUShort( data, buffAcc, entry, comp );
			case 4:
				var buff = data.bufferData[buffAcc.bufferInd];
				var pos = buffAcc.offset + (entry * buffAcc.stride) + comp * 4;
				Debug.assert(pos < buffAcc.maxPos);
				return buff.getInt32(pos);
		}
		Utils.error("Invalid compsize");
		return 0;

	}

	public static function getMatrix(data: Data, buffAcc:BuffAccess, entry:Int): h3d.Matrix {
		var floats = [];
		for (i in 0...16) {
			floats[i] = getFloat(data, buffAcc, entry, i);
		}
		var ret = new h3d.Matrix();
		ret._11 = floats[ 0];
		ret._12 = floats[ 1];
		ret._13 = floats[ 2];
		ret._14 = floats[ 3];

		ret._21 = floats[ 4];
		ret._22 = floats[ 5];
		ret._23 = floats[ 6];
		ret._24 = floats[ 7];

		ret._31 = floats[ 8];
		ret._32 = floats[ 9];
		ret._33 = floats[10];
		ret._34 = floats[11];

		ret._41 = floats[12];
		ret._42 = floats[13];
		ret._43 = floats[14];
		ret._44 = floats[15];
		return ret;
	}

	// retrieve the scalar int from a buffer access
	public static inline function getIndex(data: Data, buffAcc:BuffAccess, entry:Int):Int {
		var buff = data.bufferData[buffAcc.bufferInd];
		var pos = buffAcc.offset + (entry * buffAcc.stride);
		Debug.assert(pos < buffAcc.maxPos);
		switch (buffAcc.compSize) {
			case 1:
				return buff.get(pos);
			case 2:
				return buff.getUInt16(pos);
			case 4:
				return buff.getInt32(pos);
			default:
				throw 'Unknown index type. Component size: ${buffAcc.compSize}';
		}
	}

	public static function matNear(matA:h3d.Matrix, matB:h3d.Matrix):Bool {
		var ret = true;
		ret = ret && Math.abs(matA._11 - matB._11) < 0.0001;
		ret = ret && Math.abs(matA._12 - matB._12) < 0.0001;
		ret = ret && Math.abs(matA._13 - matB._13) < 0.0001;
		ret = ret && Math.abs(matA._14 - matB._14) < 0.0001;

		ret = ret && Math.abs(matA._21 - matB._21) < 0.0001;
		ret = ret && Math.abs(matA._22 - matB._22) < 0.0001;
		ret = ret && Math.abs(matA._23 - matB._23) < 0.0001;
		ret = ret && Math.abs(matA._24 - matB._24) < 0.0001;

		ret = ret && Math.abs(matA._31 - matB._31) < 0.0001;
		ret = ret && Math.abs(matA._32 - matB._32) < 0.0001;
		ret = ret && Math.abs(matA._33 - matB._33) < 0.0001;
		ret = ret && Math.abs(matA._34 - matB._34) < 0.0001;

		ret = ret && Math.abs(matA._41 - matB._41) < 0.0001;
		ret = ret && Math.abs(matA._42 - matB._42) < 0.0001;
		ret = ret && Math.abs(matA._43 - matB._43) < 0.0001;
		ret = ret && Math.abs(matA._44 - matB._44) < 0.0001;

		return ret;
	}

	public static function toColorString(color: Int): String {
		var colBytes = haxe.io.Bytes.alloc(3);
		var r = (color & (255 << 16)) >> 16;
		var g = (color & (255 <<  8)) >>  8;
		var b = color & 255;
		colBytes.set(0,r);
		colBytes.set(1,g);
		colBytes.set(2,b);
		return '#${colBytes.toHex()}';
	}


	public static function initializePosition( p: hxd.fmt.hmd.Data.Position )
	{
		p.x = 0.0;  p.y = 0.0;  p.z = 0.0;
		p.qx = 0.0; p.qy = 0.0; p.qz = 0.0;
		p.sx = 1.0; p.sy = 1.0; p.sz = 1.0;
	}

	public static function posFromMatrix(mat:h3d.Matrix) {
		var ret = new hxd.fmt.hmd.Data.Position();
		ret.x = mat.tx;
		ret.y = mat.ty;
		ret.z = mat.tz;
		var scale = mat.getScale();
		ret.sx = scale.x;
		ret.sy = scale.y;
		ret.sz = scale.z;
		var m = mat.clone();
		m.prependScale(1.0/scale.x, 1.0/scale.y, 1.0/scale.z);
		var qrot = new h3d.Quat();
		qrot.initRotateMatrix(m);
		if (qrot.w < 0) {
			qrot.x *= -1;
			qrot.y *= -1;
			qrot.z *= -1;
			qrot.w *= -1;
		}
		ret.qx = qrot.x;
		ret.qy = qrot.y;
		ret.qz = qrot.z;
		return ret;
	}

}
