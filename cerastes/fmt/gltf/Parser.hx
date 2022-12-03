package cerastes.fmt.gltf;

import haxe.crypto.Base64;
import h3d.Quat;
import h3d.Vector;
import haxe.Json;
import cerastes.fmt.gltf.Data;
import cerastes.fmt.gltf.Util;

import cerastes.Utils as Debug;

private enum abstract ComponentType(Int) {
	var BYTE = 5120;
	var UNSIGNED_BYTE = 5121;
	var SHORT = 5122;
	var UNSIGNED_SHORT = 5123;
	// Oddly GLTF does not seem to allow signed INTs
	var UNSIGNED_INT = 5125;
	var FLOAT = 5126;
}

private enum abstract AccessorType(String) {
	var SCALAR;
	var VEC2;
	var VEC3;
	var VEC4;
	var MAT2;
	var MAT3;
	var MAT4;
}

private enum abstract AttribName(String) to String {
	var POSITION;
	var NORMAL;
	var TANGENT;
	var TEXCOORD_0;
	var TEXCOORD_1;
	var JOINTS_0;
	var WEIGHTS_0;
}

// Convenient accessors for the "unique accessor lists" needed
// when converting to HMD

private typedef Asset = {
	version:String,
}

private typedef Buffer = {
	uri:String,
	byteLength:Int,
}

private typedef BufferView = {
	buffer:Int,
	byteLength:Int,
	byteOffset:Null<Int>,
	byteStride:Null<Int>,
}

private typedef Accessor = {
	bufferView:Int,
	componentType:ComponentType,
	byteOffset:Null<Int>,
	count:Int,
	type:AccessorType,
	min:Null<Array<Float>>,
	max:Null<Array<Float>>,
}

private typedef Primitive = {
	attributes:haxe.DynamicAccess<Int>,
	indices:Null<Int>,
	material:Null<Int>,
}

private typedef Mesh = {
	primitives:Array<Primitive>,
	name:String,
}

private typedef TextureRef = {
	index:Int,
	texCoord:Null<Int>,
}

private typedef PbrMatRough = {
	baseColorFactor:Null<Array<Float>>,
	baseColorTexture:Null<TextureRef>,
}

private typedef Material = {
	name:String,
	pbrMetallicRoughness:PbrMatRough,
}

private typedef Texture = {
	source:Int,
	sampler:Null<Int>,
}

private typedef Image = {
	uri:Null<String>,
	bufferView:Null<Int>,
	mimeType:Null<String>,
}

private typedef Sampler = {
	// TODO
}

private typedef Node = {
	children:Array<Int>,
	mesh:Null<Int>,
	skin:Null<Int>,
	translation:Null<Array<Float>>,
	rotation:Null<Array<Float>>,
	scale:Null<Array<Float>>,
	name:String,
}

private typedef Skin = {
	inverseBindMatrices:Int,
	joints:Array<Int>,
	skeleton:Null<Int>,
}

private typedef Scene = {
	nodes:Array<Int>,
	name:String,
}

private typedef AnimChannel = {
	sampler:Int,
	target: {node:Int, path: String},
}

private typedef AnimSampler = {
	input:Int,
	output:Int,
}

private typedef Animation = {
	channels:Array<AnimChannel>,
	samplers:Array<AnimSampler>,
	name:String,
}

private typedef GLTFSrcData = {
	asset:Asset,
	accessors:Array<Accessor>,
	buffers:Array<Buffer>,
	bufferViews:Array<BufferView>,
	meshes:Array<Mesh>,
	materials:Array<Material>,
	nodes:Array<Node>,
	scenes:Array<Scene>,
	textures:Array<Texture>,
	images:Array<Image>,
	skins:Null<Array<Skin>>,
	animations:Null<Array<Animation>>,
}

class Parser {
	public var srcData:GLTFSrcData;
	public var name:String;
	public var localDir:String;
	public var binChunk:haxe.io.Bytes;

	public var outData: Data;

	public function new(name, localDir, file:haxe.io.Bytes, ?binChunk:haxe.io.Bytes) {
		this.name = name;
		this.localDir = localDir;
		this.binChunk = binChunk;

		this.srcData = Json.parse(file.getString(0, file.length));

		this.outData = new Data();

		// Fixup node names before building the skin
		for (nodeInd in 0...srcData.nodes.length) {
			var node = srcData.nodes[nodeInd];
			if (node.name == null) {
				node.name = 'node_$nodeInd';
			}
		}

		loadBuffers();

		loadGeometry();

		loadSkins();

		loadMaterials();

		loadNodeTree();

		loadAnimations();

	}

	function loadBuffers() {
		// Read all files
		var buffers = srcData.buffers;
		for (bufInd in 0...buffers.length) {
			var buf = buffers[bufInd];

			var buffBytes;
			var base64Pat = ~/^data:(.*);base64,/;
			var uriStart = buf.uri != null ? buf.uri.substr(0,60) : "GLB buffer";
			if (buf.uri == null) {
				// GLB binary chunk
				Utils.assert(bufInd == 0);
				Utils.assert(binChunk != null);
				buffBytes = binChunk;

			} else if (base64Pat.match(uriStart)) {
				// This is a base64 encoded buffer, decode it
				var dataStart = buf.uri.indexOf(";base64,") + 8;
				buffBytes = Base64.decode(buf.uri.substr(dataStart));
			} else {
				#if sys
				buffBytes = sys.io.File.getBytes(localDir + buf.uri);
				#else
				throw "FIXME";
				#end
			}
			// TODO: better URI handling
			if (buffBytes.length < buf.byteLength) {
				throw 'Buffer: ${uriStart} is too small. Expected: ${buf.byteLength} bytes';
			}
			outData.bufferData.push(buffBytes);
		}
		// Load the accessors
		for (acc in srcData.accessors) {
			outData.accData.push(fillBuffAccess(acc));
		}
	}

	function checkAccessor(accInd:Int, ?expComp, ?expType) {
		var accessor = srcData.accessors[accInd];
		if (expComp != null)
			Debug.assert(accessor.componentType == expComp);
		if (expType != null)
			Debug.assert(accessor.type == expType);
	}

	function fillBuffAccess(accessor:Accessor):BuffAccess {
		var bufferView = srcData.bufferViews[accessor.bufferView];

		var compSize = componentSize(accessor.componentType);
		var numComps = numComponents(accessor.type);

		var elemSize = compSize*numComps;

		if (bufferView.byteOffset == null)
			bufferView.byteOffset = 0;

		if (accessor.byteOffset == null)
			accessor.byteOffset = 0;

		var offset = bufferView.byteOffset + accessor.byteOffset;


		var stride = (bufferView.byteStride != null) ? bufferView.byteStride : elemSize;

		var maxPos = bufferView.byteLength + bufferView.byteOffset;

		// Check the buffer view length logic
		Debug.assert( (accessor.byteOffset+stride*(accessor.count-1)+elemSize) <= bufferView.byteLength);

		return {
			bufferInd: bufferView.buffer,
			offset: offset,
			stride: stride,
			compSize: compSize,
			numComps: numComps,
			count: accessor.count,
			maxPos: maxPos,
		};
	}

	function loadGeometry() {
		for (mesh in srcData.meshes) {
			var meshData = new MeshData();
			meshData.name = mesh.name;
			for (prim in mesh.primitives) {
				var primData = new PrimitiveData();
				primData.accList = [-1, -1, -1, -1, -1, -1];
				primData.matInd = prim.material;
				var posAcc = prim.attributes.get(POSITION);
				var vertCount = srcData.accessors[posAcc].count;
				primData.pos = posAcc;
				checkAccessor(posAcc, FLOAT, VEC3);
				primData.accList[POS] = posAcc;
				var norAcc = prim.attributes.get(NORMAL);
				if (norAcc != null) {
					primData.norm = norAcc;
					checkAccessor(norAcc, FLOAT, VEC3);
					primData.accList[NOR] = norAcc;
					Debug.assert(srcData.accessors[norAcc].count >= vertCount);
				}
				var texAcc = prim.attributes.get(TEXCOORD_0);
				if (texAcc != null) {
					primData.texCoord = texAcc;
					checkAccessor(texAcc, FLOAT, VEC2);
					primData.accList[TEX] = texAcc;
					Debug.assert(srcData.accessors[texAcc].count >= vertCount);
				}
				var jointsAcc = prim.attributes.get(JOINTS_0);
				if (jointsAcc != null) {
					primData.joints = jointsAcc;
					// @todo: Blender exports these as bytes, not ushorts. We handle both cases, but don't
					// have a good assert func here yet
					//checkAccessor(jointsAcc, UNSIGNED_SHORT, VEC4);
					primData.accList[JOINTS] = jointsAcc;
					Debug.assert(srcData.accessors[jointsAcc].count >= vertCount);
				}
				var weightsAcc = prim.attributes.get(WEIGHTS_0);
				if (weightsAcc != null) {
					primData.weights = weightsAcc;
					checkAccessor(weightsAcc, FLOAT, VEC4);
					primData.accList[WEIGHTS] = weightsAcc;
					Debug.assert(srcData.accessors[weightsAcc].count >= vertCount);
				}
				// Assert we have both or neither of joints and weights
				Debug.assert((weightsAcc == null) == (jointsAcc == null));

				primData.indices = prim.indices;
				if (primData.indices != null) {
					primData.accList[INDICES] = prim.indices;
					checkAccessor(prim.indices, null, SCALAR);
				}

				meshData.primitives.push(primData);
			}
			outData.meshes.push(meshData);
		}
	}

	function loadSkins() {
		if (srcData.skins == null) return;
		for (skin in srcData.skins) {
			var skinData = new SkinData();
			skinData.invBindMatAcc = skin.inverseBindMatrices;
			checkAccessor(skinData.invBindMatAcc, FLOAT, MAT4);
			skinData.joints = skin.joints;

			// Save the names and check that they are unique
			skinData.jointNameMap = new Map();

			for (i in 0...skinData.joints.length) {
				var nodeId = skinData.joints[i];
				var nodeName = srcData.nodes[nodeId].name;
				Debug.assert(nodeName != null);
				if (skinData.jointNameMap[nodeName] != null) {
					throw 'Skin node name is used twice: $nodeName';
				}
				skinData.jointNameMap[nodeName] = i;
			}
			outData.skins.push(skinData);
		}
	}

	function loadMaterials() {
		for (mat in srcData.materials) {
			var matData = new MaterialData();
			matData.name = mat.name;
			var metalRough = mat.pbrMetallicRoughness;
			if (metalRough.baseColorFactor != null) {
				var bc = metalRough.baseColorFactor;
				Debug.assert(bc.length >= 3);
				var colVec = new h3d.Vector(bc[0], bc[1], bc[2], bc.length >= 4 ? bc[3] : 1.0);
				matData.color = colVec.toColor();
			}
			if (metalRough.baseColorTexture != null) {
				var bc = metalRough.baseColorTexture;
				var texInd = bc.index;
				var texCoord = bc.texCoord != null ? bc.texCoord : 0;
				Debug.assert(texCoord == 0, "Only texcoord 0 supported for now");

				var tex = srcData.textures[texInd];
				var imageInd = tex.source;
				var image = srcData.images[imageInd];

				if(image.uri != null) {
					matData.colorTex = File(image.uri);
				} else if(image.bufferView != null) {
					var ext = switch(image.mimeType) {
						case "image/png": "PNG";
						case "image/jpeg": "JPG";
						default:
							throw "unknown image type";
					}
					var bufView = srcData.bufferViews[image.bufferView];
					matData.colorTex = Buffer(bufView.buffer, bufView.byteOffset, bufView.byteLength,ext);
				} else {
					Debug.assert(false, "Image must have either a bufferView or URI");
				}
			}

			outData.mats.push(matData);
		}
	}

	// Find the appropriate interval and weights from a time input curve
	function interpAnimSample(inAcc:BuffAccess, time:Float):SampleInterp {
		// Find the nearest input values
		var lastVal = Util.getFloat(outData, inAcc, 0,0);
		if (time <= lastVal) {
			return { ind0: 0, weight: 1.0, ind1:-1};
		}
		// Iterate until we reach the appropriate interval
		// TODO: something much less inefficient
		var nextVal = 0.0;
		var nextInd = 1;
		while(nextInd < inAcc.count) {
			nextVal = Util.getFloat(outData, inAcc, nextInd, 0);
			if (nextVal > time) {
				break;
			}
			Debug.assert(nextVal >= lastVal);
			lastVal = nextVal;
			nextInd++;
		}
		var lastInd = nextInd-1;

		if (nextInd == inAcc.count) {
			return { ind0: lastInd, weight: 1.0, ind1:-1};
		}

		Debug.assert(nextVal >= lastVal);
		Debug.assert(lastVal <= time);
		Debug.assert(time <= nextVal);
		if (nextVal == lastVal) {
			//Divide by zero guard
			return { ind0: lastInd, weight: 1.0, ind1:-1};
		}

		// calc weight
		var w = (nextVal-time)/(nextVal-lastVal);

		return { ind0: lastInd, weight: w, ind1:nextInd};

	}

	function loadAnimations() {
		if (srcData.animations == null) return;
		for (anim in srcData.animations) {
			// Figure out start and end times
			var startTime = Math.POSITIVE_INFINITY;
			var endTime = Math.NEGATIVE_INFINITY;
			for (chan in anim.channels) {
				var sampId = chan.sampler;
				var samp = anim.samplers[sampId];
				var inAcc = srcData.accessors[samp.input];
				if (inAcc.max != null) {
					var end = inAcc.max[0];
					endTime = Math.max(endTime, end);
				}
				if (inAcc.min != null) {
					var start = inAcc.min[0];
					startTime = Math.min(startTime, start);
				}
			}
			var length = endTime - startTime;
			var numFrames = Std.int(length * Data.SAMPLE_RATE);

			function sampleCurve(sampId, numComps, isQuat) {
				var samp = anim.samplers[sampId];
				var inAcc = outData.accData[samp.input];
				var outAcc = outData.accData[samp.output];
				Debug.assert(outAcc.numComps == numComps);
				var values = new Array();
				values.resize(numFrames*outAcc.numComps);
				var vals0 = new Array();
				vals0.resize(numComps);
				var vals1 = new Array();
				vals1.resize(numComps);
				for (f in 0...numFrames) {
					var time = startTime+f*(1/Data.SAMPLE_RATE);
					var samp = interpAnimSample(inAcc, time);
					if (samp.ind1 == -1) {
						for (i in 0...numComps) {
							values[f*numComps+i] = Util.getFloat(outData, outAcc, samp.ind0, i);
						}
						continue;
					}
					// Otherwise fill up the two values and interpolate
					for (i in 0...numComps) {
						vals0[i] = Util.getFloat(outData, outAcc, samp.ind0, i);
						vals1[i] = Util.getFloat(outData, outAcc, samp.ind1, i);
					}
					if (!isQuat) {
						// Simple lerp
						for (i in 0...numComps) {
							values[f*numComps+i] = vals0[i]*samp.weight + vals1[i]*(1.0-samp.weight);
						}
					} else {
						Debug.assert(numComps == 4);
						// Quaternion weirdness
						var q0 = new Quat(vals0[0], vals0[1], vals0[2], vals0[3]);
						var q1 = new Quat(vals1[0], vals1[1], vals1[2], vals1[3]);

						q0.lerp(q0, q1, samp.weight, true);
						values[f*numComps + 0] = q0.x;
						values[f*numComps + 1] = q0.y;
						values[f*numComps + 2] = q0.z;
						values[f*numComps + 3] = q0.w;
					}

				}
				return values;
			}

			var curves = [];
			var curvesPerNode : Map<Int, Array<AnimChannel>> = new Map();

			for (chan in anim.channels) {
				var nodeId = chan.target.node;
				var nodeList = curvesPerNode[nodeId];
				if (nodeList == null) {
					nodeList = [];
					curvesPerNode[nodeId] = nodeList;
				}
				nodeList.push(chan);
			}

			for (nodeId => channels in curvesPerNode) {
				var transPred = (chan) -> chan.target.path == "translation";
				var rotPred = (chan) -> chan.target.path == "rotation";
				var scalePred = (chan) -> chan.target.path == "scale";

				var numTrans = Lambda.count(channels, transPred);
				var numRot = Lambda.count(channels, rotPred);
				var numScale = Lambda.count(channels, scalePred);
				Debug.assert(numTrans <= 1);
				Debug.assert(numRot <= 1);
				Debug.assert(numScale <= 1);

				var curve = new AnimationCurve();
				curve.targetNode = nodeId;
				curve.targetName = srcData.nodes[nodeId].name;

				if (numTrans != 0) {
					var transChan = Lambda.filter(channels, transPred)[0];
					curve.transValues = sampleCurve(transChan.sampler, 3, false);
				}

				if (numRot != 0) {
					var rotChan = Lambda.filter(channels, rotPred)[0];
					curve.rotValues = sampleCurve(rotChan.sampler, 4, true);
				}

				if (numScale != 0) {
					var scaleChan = Lambda.filter(channels, scalePred)[0];
					curve.scaleValues = sampleCurve(scaleChan.sampler, 3, false);
				}

				curves.push(curve);
			}

			var animData = new AnimationData();
			animData.curves = curves;
			animData.length = length;
			animData.numFrames = numFrames;
			animData.name = anim.name;
			outData.animations.push(animData);
		}

		// Mark all nodes as animated if it or any of its parents are animated
		for (node in outData.nodes) {
			var n = node;
			while (n != null) {
				if (n.animCurves.length != 0) {
					node.isAnimated = true;
					break;
				}
				n = n.parent;
			}
		}
	}

	// Fill the data for this node, and recurse into its children
	function buildNode(curNode:NodeData, nodeInd:Int) {
		outData.nodes[nodeInd] = curNode;

		var n = srcData.nodes[nodeInd];
		curNode.nodeInd = nodeInd;
		curNode.name = n.name;

		if (n.translation != null) {
			curNode.trans = new Vector(
				n.translation[0],
				n.translation[1],
				n.translation[2]);
		}
		if (n.scale != null) {
			curNode.scale = new Vector(
				n.scale[0],
				n.scale[1],
				n.scale[2]);
		}
		if (n.rotation != null) {
			curNode.rot = new Quat(
				n.rotation[0],
				n.rotation[1],
				n.rotation[2],
				n.rotation[3]);
		}
		if (n.mesh != null) {
			curNode.mesh = n.mesh;
			curNode.hasChildMesh = true;

			// Mark all ancestors
			var par = curNode.parent;
			while(par != null) {
				if (par.hasChildMesh) break;

				par.hasChildMesh = true;
				par = par.parent;
			}
		}
		if (n.skin != null) {
			curNode.skin = n.skin;
		}
		if (n.children != null) {
			for (cInd in n.children) {
				var c = srcData.nodes[cInd];
				var child = new NodeData();
				curNode.children.push(child);
				child.parent = curNode;
				buildNode(child, cInd);
			}
		}
	}

	function markJoints(node: NodeData) {
		node.isJoint = true;
		for (c in node.children) {
			markJoints(c);
		}
	}

	function loadNodeTree() {
		outData.nodes.resize(srcData.nodes.length);

		for (scene in srcData.scenes) {
			for (nodeInd in scene.nodes) {
				var node = new NodeData();
				outData.rootNodes.push(node);
				buildNode(node, nodeInd);
			}
		}

		// Mark all nodes listed in a skin as a joint
		for (skin in outData.skins) {
			for (nodeInd in skin.joints) {
				outData.nodes[nodeInd].isJoint = true;
			}
		}
		for (node in outData.nodes) {
			// For now do not allow joints to have meshes
			Debug.assert(!node.isJoint || !node.hasChildMesh);
			if (node.isJoint) {
				for (c in node.children) {
					Debug.assert(c.isJoint);
				}
			}
		}
	}

	static function componentSize(compType:ComponentType):Int {
		return switch (compType) {
			case BYTE:
				1;
			case UNSIGNED_BYTE:
				1;
			case SHORT:
				2;
			case UNSIGNED_SHORT:
				2;
			case UNSIGNED_INT:
				4;
			case FLOAT:
				4;
			default:
				throw 'Unknown component $compType';
		}
	}

	static function numComponents(accType:AccessorType):Int {
		return switch (accType) {
			case SCALAR:
				1;
			case VEC2:
				2;
			case VEC3:
				3;
			case VEC4:
				4;
			case MAT2:
				4;
			case MAT3:
				9;
			case MAT4:
				16;
			default:
				throw 'Unknown accessor type $accType';
		}
	}

	public function getData() {
		return outData;
	}

	public static function parseGLTF(name, localDir, file:haxe.io.Bytes) {
		var parser = new Parser(name, localDir, file);
		return parser.getData();
	}

	public static function parseGLB(name, localDir, file:haxe.io.Bytes) {
		// Read header
		var magic = file.getString(0, 4);
		Debug.assert(magic == "glTF");
		var fileVer = file.getInt32(4);
		Debug.assert(fileVer == 2);
		var fileLen = file.getInt32(8);
		Debug.assert(fileLen <= file.length);

		var jsonChunkStart = 12;
		// Read the JSON chunk
		var jsonChunkLen = file.getInt32(jsonChunkStart);
		Debug.assert(fileLen >= jsonChunkStart+8+jsonChunkLen);
		var jsonType = file.getString(jsonChunkStart+4,4);
		Debug.assert(jsonType == "JSON");
		var jsonBytes = file.sub(jsonChunkStart+8,jsonChunkLen);

		// Optional binary chunk
		var binChunkStart = jsonChunkStart + jsonChunkLen + 8;
		var binBytes = null;
		if (binChunkStart<fileLen) {
			var binChunkLen = file.getInt32(binChunkStart);
			Debug.assert(fileLen >= binChunkStart+8+binChunkLen);
			var binType = file.getString(binChunkStart+4,3);
			Debug.assert(binType == "BIN");
			binBytes = file.sub(binChunkStart+8,binChunkLen);
		}
		var parser = new Parser(name, localDir, jsonBytes, binBytes);
		return parser.getData();
	}
}
