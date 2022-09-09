package cerastes.fmt.gltf;

import h3d.Quat;

enum abstract AccessorInd(Int) to Int {
	var POS = 0;
	var NOR;
	var TEX;
	var JOINTS;
	var WEIGHTS;
	var INDICES;
	var TAN;
}

class MeshData {
	public var primitives:Array<PrimitiveData> = [];
	public var name:String;
	public var uses:Int = 0;

	public function new() {}
}

class SkinData {
	public var invBindMatAcc: Int;
	public var skeleton: Null<Int>;
	public var joints: Array<Int>;
	public var jointNameMap: Map<String, Int>;
	public function new() {}
}

enum TextureData {
	File(fileName:String);
	Buffer(buff:Int,pos:Int,len:Int,ext:String);
}

class MaterialData {
	public var color:Null<Int>;
	public var colorTex:TextureData;

	public var name:String;

	public function new() {}
}

class NodeData {
	public var nodeInd: Int;
	public var name: String;
	public var parent: Null<NodeData> = null;
	public var children: Array<NodeData> = [];

	public var trans: Null<h3d.Vector> = null;
	public var rot: Null<Quat> = null;
	public var scale: Null<h3d.Vector> = null;

	public var outputID: Int = -1;

	public var mesh: Null<Int> = null;
	public var skin: Null<Int> = null;
	public var hasChildMesh: Bool = false;
	public var isJoint: Bool = false;
	public var isAnimated: Bool = false;
	public var animCurves: Array<AnimationCurve> = [];

	public function new() {}
}

typedef BuffAccess = {
	bufferInd:Int,
	offset:Int,
	stride:Int,
	compSize:Int,
	numComps:Int,
	count:Int,
	maxPos:Int,
}

typedef SampleInterp = {
	ind0:Int,
	ind1:Int,
	weight:Float,
}

class PrimitiveData {
	public var matInd:Null<Int>;

	public var pos:Int;
	public var norm:Null<Int>;
	public var tan:Null<Int>;
	public var texCoord:Null<Int>;
	public var joints:Null<Int>;
	public var weights:Null<Int>;
	public var indices:Null<Int>;
	public var accList:Array<Int>;

	public function new() {}
}


class AnimationCurve {
	public var transValues: Null<Array<Float>>;
	public var rotValues: Null<Array<Float>>;
	public var scaleValues: Null<Array<Float>>;
	public var targetName: String;
	public var targetNode: Int;

	public function new() {}
}

class AnimationData {
	public var length: Float;
	public var numFrames: Int;
	public var curves: Array<AnimationCurve>;
	public var name: String;

	public function new() {}
}

class Data {
	public static final SAMPLE_RATE = 60.0;

	public var bufferData: Array<haxe.io.Bytes> = [];
	public var accData: Array<BuffAccess> = [];
	public var meshes: Array<MeshData> = [];
	public var mats: Array<MaterialData> = [];
	public var rootNodes: Array<NodeData> = [];
	public var nodes: Array<NodeData> = []; // The data for the nodes in the same order as the source
	public var skins: Array<SkinData> = [];
	public var animations: Array<AnimationData> = [];
	public function new() {}
}

