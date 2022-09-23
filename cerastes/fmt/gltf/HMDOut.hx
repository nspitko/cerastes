package cerastes.fmt.gltf;

import h3d.Quat;
import h3d.Vector;
import h3d.col.Bounds;
import hxd.fmt.hmd.Data;

import cerastes.fmt.gltf.Data;
import cerastes.Utils as Debug;

class HMDOut {

	var gltfData: Data;
	var name: String;
	var relDir: String;

	public function new(name:String, relDir:String, data: Data) {
		this.name = name;
		this.relDir = relDir;
		this.gltfData = data;
	}

	public function toHMD():hxd.fmt.hmd.Data {
		var outBytes = new haxe.io.BytesOutput();

		// Emit the geometry

		// Emit unique combinations of accessors
		// as a single buffer to save data
		var geoMap = new SeqIntMap();
		for (mesh in gltfData.meshes) {
			for (prim in mesh.primitives) {
				geoMap.add(prim.accList);
			}
		}

		// Map from the entries in geoMap to
		// data positions
		var dataPos = [];
		var bounds = [];

		// Emit one HMD geometry per unique primitive combo
		for (i in 0...geoMap.count) {
			dataPos.push(outBytes.length);
			var bb = new Bounds();
			bb.empty();
			bounds.push(bb);

			var accList = geoMap.getList(i);
			var hasNorm = accList[NOR] != -1;
			var hasTex = accList[TEX] != -1;
			var hasJoints = accList[JOINTS] != -1;
			var hasWeights = accList[WEIGHTS] != -1;
			var hasIndices = accList[INDICES] != -1;
			var hasTangents = accList[TAN] != -1;

			// We do not support generating normals on models that use indices (yet)
			Debug.assert(hasNorm || !hasIndices);

			Debug.assert(hasJoints == hasWeights);

			var posAcc = gltfData.accData[accList[POS]];
			var normAcc = gltfData.accData[accList[NOR]];
			var uvAcc = gltfData.accData[accList[TEX]];
			var tanAcc = gltfData.accData[accList[TAN]];

			var genNormals = null;
			if (!hasNorm) {
				genNormals = generateNormals(posAcc);
			}

			if( !hasTangents )
				throw "!! No tangents!!";

			//var tangents = generateTangents(posAcc, normAcc, uvAcc);


			var norAcc = gltfData.accData[accList[NOR]];
			var texAcc = gltfData.accData[accList[TEX]];
			var jointAcc = hasJoints ? gltfData.accData[accList[JOINTS]] : null;
			var weightAcc = hasWeights ? gltfData.accData[accList[WEIGHTS]] : null;

			for (i in 0...posAcc.count) {
				// Position data
				var x = Util.getFloat(gltfData, posAcc, i, 0);
				outBytes.writeFloat(x);
				var y = Util.getFloat(gltfData, posAcc, i, 1);
				outBytes.writeFloat(y);
				var z = Util.getFloat(gltfData, posAcc, i, 2);
				outBytes.writeFloat(z);
				bb.addPos(x, y, z);

				// Normal data
				if (hasNorm) {
					outBytes.writeFloat(Util.getFloat(gltfData, norAcc, i, 0));
					outBytes.writeFloat(Util.getFloat(gltfData, norAcc, i, 1));
					outBytes.writeFloat(Util.getFloat(gltfData, norAcc, i, 2));
				} else {
					var norm = genNormals[Std.int(i/3)];
					outBytes.writeFloat(norm.x);
					outBytes.writeFloat(norm.y);
					outBytes.writeFloat(norm.z);
				}

				if( hasTangents )
				{
					outBytes.writeFloat(Util.getFloat(gltfData, tanAcc, i, 0));
					outBytes.writeFloat(Util.getFloat(gltfData, tanAcc, i, 1));
					outBytes.writeFloat(Util.getFloat(gltfData, tanAcc, i, 2));
				}
				else
				{
					// Reserve space for tangent data (We'll optionally fix it up later
					outBytes.writeFloat(0);
					outBytes.writeFloat(0);
					outBytes.writeFloat(0);
				}


				// Tex coord data
				if (hasTex) {
					outBytes.writeFloat(Util.getFloat(gltfData, texAcc, i, 0));
					outBytes.writeFloat(Util.getFloat(gltfData, texAcc, i, 1));
				} else {
					outBytes.writeFloat(0.5);
					outBytes.writeFloat(0.5);
				}

				if (hasJoints) {
					for (jInd in 0...4) {
						var joint = Util.getInt(gltfData, jointAcc, i, jInd);
						Debug.assert(joint >= 0);
						outBytes.writeByte(joint);
					}
					//outBytes.writeByte(0);
				}
				if (hasWeights) {
					for (wInd in 0...4) {
						var wVal = Util.getFloat(gltfData, weightAcc, i, wInd);
						Debug.assert(!Math.isNaN(wVal));

						outBytes.writeFloat(wVal);
					}
				}
			}
		}

		// Find the unique combination of accessor lists in each
		// mesh. This will map on to the HMD geometry concept
		var meshAccLists:Array<Array<Int>> = [];
		for (mesh in gltfData.meshes) {
			var accs = Lambda.map(mesh.primitives, (prim) -> geoMap.add(prim.accList));
			accs.sort((a, b) -> a - b);
			var uniqueAccs = [];
			var last = -1;
			for (a in accs) {
				if (a != last) {
					uniqueAccs.push(a);
					last = a;
				}
			}
			meshAccLists.push(uniqueAccs);
		}

		var geos = [];
		var geoMaterials:Array<Array<Int>> = [];

		// Generate a geometry for each mesh-accessor
		// Also retain the materials used
		var meshToGeoMap:Array<Array<Int>> = [];
		for (meshInd in 0...gltfData.meshes.length) {
			var meshGeoList = [];
			meshToGeoMap.push(meshGeoList);

			var accList = meshAccLists[meshInd];
			for (accSet in accList) {
				var accessors = geoMap.getList(accSet);
				var posAcc = gltfData.accData[accessors[0]];

				var geo = new Geometry();
				var geoMats = [];
				meshGeoList.push(geos.length);
				geos.push(geo);
				geoMaterials.push(geoMats);
				geo.props = null;
				geo.vertexCount = posAcc.count;
				geo.vertexStride = 11;

				geo.vertexFormat = [];
				geo.vertexFormat.push(new GeometryFormat("position", DVec3));
				geo.vertexFormat.push(new GeometryFormat("normal", DVec3));
				geo.vertexFormat.push(new GeometryFormat("tangent", DVec3));
				geo.vertexFormat.push(new GeometryFormat("uv", DVec2));
				geo.vertexPosition = dataPos[accSet];
				geo.bounds = bounds[accSet];

				if (accessors[3] != -1) {
					// Has joint and weight data
					geo.vertexStride += 5;
					geo.vertexFormat.push(new GeometryFormat("indexes", DBytes4));
					geo.vertexFormat.push(new GeometryFormat("weights", DVec4));
				}

				var mesh = gltfData.meshes[meshInd];

				// @todo



				var indexList = [];
				// Iterate the primitives and add indices for this geo
				for (prim in mesh.primitives) {
					var primAccInd = geoMap.add(prim.accList);
					if (accSet != primAccInd)
						continue; // Different geo

					var matInd = geoMats.indexOf(prim.matInd);
					if (matInd == -1) {
						// First use of this mat
						matInd = geoMats.length;
						geoMats.push(prim.matInd);
						indexList.push([]);
					}
					// Fill the index list
					if (prim.indices != null) {
						var iList = indexList[matInd];
						var indexAcc = gltfData.accData[prim.indices];
						for (i in 0...indexAcc.count) {
							iList.push(Util.getIndex(gltfData, indexAcc, i));
						}
					} else {
						indexList[matInd] = [for (i in 0...geo.vertexCount) i];
					}
				}

				// Emit the indices
				geo.indexPosition = outBytes.length;
				geo.indexCounts = Lambda.map(indexList, (x) -> x.length);
				for (inds in indexList) {
					for (i in inds) {
						outBytes.writeUInt16(i);
					}
				}
			}
		}

		var inlineImages = [];
		var materials = [];
		for (matInd in 0...gltfData.mats.length) {
			var mat = gltfData.mats[matInd];
			var hMat = new hxd.fmt.hmd.Material();
			hMat.name = mat.name;

			if (mat.colorTex != null) {
				switch(mat.colorTex) {
					case File(fileName):
						hMat.diffuseTexture = relDir + fileName;
					case Buffer(buff, pos, len, ext): {
						inlineImages.push(
							{ buff:buff, pos:pos, len:len, ext:ext, mat:matInd });
					}
				}
			} else if (mat.color != null) {
				hMat.diffuseTexture = Util.toColorString(mat.color);
			} else {
				hMat.diffuseTexture = Util.toColorString(0);
			}
			hMat.blendMode = None;
			materials.push(hMat);
		}

		var identPos = new hxd.fmt.hmd.Position();
		Util.initializePosition( identPos );

		var models = [];
		var rootModel = new Model();
		rootModel.name = this.name;
		rootModel.props = null;
		rootModel.parent = -1;
		rootModel.follow = null;
		rootModel.position = identPos;
		rootModel.skin = null;
		rootModel.geometry = -1;
		rootModel.materials = null;
		models[0] = rootModel;

		var nextOutID = 1;
		for (n in gltfData.nodes) {
			// Mark the slot the node will be put into
			// while skipping over joints
			if (!n.isJoint) {
				n.outputID = nextOutID++;
			}
		}

		for (i in 0...gltfData.nodes.length) {
			// Sanity check
			var node = gltfData.nodes[i];
			Debug.assert(node.nodeInd == i);
			if (node.isJoint)
				continue;

			var model = new Model();
			model.name = node.name;
			model.props = null;
			model.parent = node.parent != null ? node.parent.outputID: 0;
			model.follow = null;
			model.position = nodeToPos(node);
			model.skin = null;
			if (node.mesh != null) {
				if (node.skin != null) {
					model.skin = buildSkin(gltfData.skins[node.skin], node.name);
					//model.skin = null;
				}

				var geoList = meshToGeoMap[node.mesh];
				if(geoList.length == 1) {
					// We can put the single geometry in this node
					model.geometry = geoList[0];
					model.materials = geoMaterials[geoList[0]];
				} else {
					model.geometry = -1;
					model.materials = null;
					// We need to generate a model per primitive
					for (geoInd in geoList) {
						var primModel = new Model();
						primModel.name = gltfData.meshes[node.mesh].name;
						primModel.props = null;
						primModel.parent = node.outputID;
						primModel.position = identPos;
						primModel.follow = null;
						primModel.skin = null;
						primModel.geometry = geoInd;
						primModel.materials = geoMaterials[geoInd];
						models[nextOutID++] = primModel;
					}
				}

			} else {
				model.geometry = -1;
				model.materials = null;
			}
			models[node.outputID] = model;
		}

		// Populate animation information and fill data
		var anims = [];
		for (animData in gltfData.animations) {
			var anim = new hxd.fmt.hmd.Data.Animation();
			anim.name = animData.name;
			anim.props = null;
			anim.frames = animData.numFrames;
			anim.sampling = Data.SAMPLE_RATE;
			anim.speed = 1.0;
			anim.loop = false;
			anim.objects = [];
			for (curveData in animData.curves) {
				var animObject = new hxd.fmt.hmd.Data.AnimationObject();
				animObject.name = curveData.targetName;

				if (curveData.transValues != null) {
					animObject.flags.set(HasPosition);
				}
				if (curveData.rotValues != null) {
					animObject.flags.set(HasRotation);
				}
				if (curveData.scaleValues != null) {
					animObject.flags.set(HasScale);
				}
				anim.objects.push(animObject);
			}
			// Fill in the animation data
			anim.dataPosition = outBytes.length;
			for (f in 0...anim.frames) {
				for (curve in animData.curves) {
					if (curve.transValues != null) {
						outBytes.writeFloat(curve.transValues[f*3+0]);
						outBytes.writeFloat(curve.transValues[f*3+1]);
						outBytes.writeFloat(curve.transValues[f*3+2]);
					}
					if (curve.rotValues != null) {
						var quat = new Quat(
							curve.rotValues[f*4+0],
							curve.rotValues[f*4+1],
							curve.rotValues[f*4+2],
							curve.rotValues[f*4+3]);
						var qLength = quat.length();
						Debug.assert(Math.abs(qLength-1.0) < 0.2);
						quat.normalize();
						if (quat.w < 0) {
							quat.w*= -1;
							quat.x*= -1;
							quat.y*= -1;
							quat.z*= -1;
						}
						outBytes.writeFloat(quat.x);
						outBytes.writeFloat(quat.y);
						outBytes.writeFloat(quat.z);
					}
					if (curve.scaleValues != null) {
						outBytes.writeFloat(curve.scaleValues[f*3+0]);
						outBytes.writeFloat(curve.scaleValues[f*3+1]);
						outBytes.writeFloat(curve.scaleValues[f*3+2]);
					}
				}
			}
			anims.push(anim);

		}

		// Append any inline images to the binary data
		for (img in inlineImages) {
			// Generate a new texture string using the relative-texture format
			var mat = materials[img.mat];
			mat.diffuseTexture = '${img.ext}@${outBytes.length}--${img.len}';

			var imageBytes = gltfData.bufferData[img.buff].sub(img.pos, img.len);
			outBytes.writeBytes(imageBytes, 0, img.len);
		}

		var ret = new hxd.fmt.hmd.Data();
		#if hmd_version
		ret.version = Std.parseInt(#if macro haxe.macro.Context.definedValue("hmd_version") #else haxe.macro.Compiler.getDefine("hmd_version") #end);
		#else
		ret.version = hxd.fmt.hmd.Data.CURRENT_VERSION;
		#end
		ret.props = null;
		ret.materials = materials;
		ret.geometries = geos;
		ret.models = models;
		ret.animations = anims;
		ret.dataPosition = 0;

		ret.data = outBytes.getBytes();

		return ret;
	}

	function makePosition( m : h3d.Matrix ) {
		var p = new Position();
		var s = m.getScale();
		var q = new h3d.Quat();
		q.initRotateMatrix(m);
		q.normalize();
		if( q.w < 0 ) q.negate();
		p.sx = round(s.x);
		p.sy = round(s.y);
		p.sz = round(s.z);
		p.qx = round(q.x);
		p.qy = round(q.y);
		p.qz = round(q.z);
		p.x = round(m._41);
		p.y = round(m._42);
		p.z = round(m._43);
		return p;
	}

	/**
		Keep high precision values. Might increase animation data size and compressed size.
	**/
	public var highPrecision : Bool = false;

	function round(v:Float) {
		if( v != v ) throw "NaN found";
		return highPrecision ? v : std.Math.fround(v * 131072) / 131072;
	}

	function buildSkin(skin:SkinData, nodeName): hxd.fmt.hmd.Data.Skin {
		var ret = new hxd.fmt.hmd.Data.Skin();
		ret.name = (skin.skeleton != null ? gltfData.nodes[skin.skeleton].name : nodeName) + "_skin";
		ret.props = [FourBonesByVertex]; // @todo should this go here or in sj?
		ret.split = null;
		ret.joints = [];
		for (i in 0...skin.joints.length) {
			var jInd = skin.joints[i];
			var sj = new hxd.fmt.hmd.Data.SkinJoint();
			var node = gltfData.nodes[jInd];
			sj.name = node.name;
			sj.props = null;
			sj.position = nodeToPos(node);
			sj.parent = skin.joints.indexOf(node.parent.nodeInd);
			sj.bind = i;

			// Get invBindMatrix
			var invBindMat = Util.getMatrix(gltfData,gltfData.accData[skin.invBindMatAcc], i);
			sj.transpos = Util.posFromMatrix(invBindMat);
			// Copied from the FBX loader... Oh no......
			if( sj.transpos.sx != 1 || sj.transpos.sy != 1 || sj.transpos.sz != 1 ) {
				// FIX : the scale is not correctly taken into account, this formula will extract it and fix things
				var tmp = Util.posFromMatrix(invBindMat).toMatrix();
				tmp.transpose();
				var s = tmp.getScale();
				tmp.prependScale(1 / s.x, 1 / s.y, 1 / s.z);
				tmp.transpose();
				sj.transpos = makePosition(tmp);
				sj.transpos.sx = round(s.x);
				sj.transpos.sy = round(s.y);
				sj.transpos.sz = round(s.z);
			}
			// Ensure this matrix converted to a 'Position' correctly
			var testMat = sj.transpos.toMatrix();
			//var testPos = Position.fromMatrix(testMat);
			//Debug.assert(Util.matNear(invBindMat, testMat));

			ret.joints.push(sj);
		}


		return ret;
	}

	function generateNormals(posAcc:BuffAccess) : Array<Vector> {
		Debug.assert(posAcc.count % 3 == 0);
		var numTris = Std.int(posAcc.count / 3);
		var ret = [];
		for (i in 0...numTris) {

			var ps = [];
			for (p in 0...3) {
				ps.push(new Vector(
					Util.getFloat(gltfData, posAcc, i*3+p,0),
					Util.getFloat(gltfData, posAcc, i*3+p,1),
					Util.getFloat(gltfData, posAcc, i*3+p,2)));
			}
			var d0 = ps[1].sub(ps[0]);
			var d1 = ps[2].sub(ps[1]);
			ret.push(d0.cross(d1));
		}
		return ret;

	}
	function nodeToPos(node: NodeData): Position {
		var ret = new Position();
		if (node.trans != null) {
			ret.x = node.trans.x;
			ret.y = node.trans.y;
			ret.z = node.trans.z;
		} else {
			ret.x = 0.0;
			ret.y = 0.0;
			ret.z = 0.0;
		}
		if (node.rot != null) {
			var posW = node.rot.w > 0.0;
			ret.qx = node.rot.x * (posW?1.0:-1.0);
			ret.qy = node.rot.y * (posW?1.0:-1.0);
			ret.qz = node.rot.z * (posW?1.0:-1.0);
		} else {
			ret.qx = 0.0;
			ret.qy = 0.0;
			ret.qz = 0.0;
		}
		if (node.scale != null) {
			ret.sx = node.scale.x;
			ret.sy = node.scale.y;
			ret.sz = node.scale.z;
		} else {
			ret.sx = 1.0;
			ret.sy = 1.0;
			ret.sz = 1.0;
		}
		return ret;
	}

	function generateTangents( posAcc: BuffAccess, normAcc: BuffAccess, uvAcc: BuffAccess ) : Array<Vector>
	{
		/*
		#if (hl && !hl_disable_mikkt && (haxe_ver >= "4.0"))
		Debug.assert(posAcc.count % 3 == 0);
		Debug.assert(normAcc.count % 3 == 0);



		var m = new hl.Format.Mikktspace();
		m.buffer = new hl.Bytes(8 * 4 * posAcc.count);
		m.stride = 8;
		m.xPos = 0;
		m.normalPos = 3;
		m.uvPos = 6;

		m.indexes = new hl.Bytes(4 * index.vidx.length);
		m.indices = index.vidx.length;

		m.tangents = new hl.Bytes(4 * 4 * index.vidx.length);
		(m.tangents:hl.Bytes).fill(0,4 * 4 * index.vidx.length,0);
		m.tangentStride = 4;
		m.tangentPos = 0;

		var out = 0;


		for (i in 0...posAcc.count) {
			// Position data
			var x = Util.getFloat(gltfData, posAcc, i, 0);
			outBytes.writeFloat(x);
			var y = Util.getFloat(gltfData, posAcc, i, 1);
			outBytes.writeFloat(y);
			var z = Util.getFloat(gltfData, posAcc, i, 2);
			outBytes.writeFloat(z);
			bb.addPos(x, y, z);

			// Normal data
			if (hasNorm) {
				outBytes.writeFloat(Util.getFloat(gltfData, norAcc, i, 0));
				outBytes.writeFloat(Util.getFloat(gltfData, norAcc, i, 1));
				outBytes.writeFloat(Util.getFloat(gltfData, norAcc, i, 2));
			} else {
				var norm = genNormals[Std.int(i/3)];
				outBytes.writeFloat(norm.x);
				outBytes.writeFloat(norm.y);
				outBytes.writeFloat(norm.z);
			}

			// Tex coord data
			if (hasTex) {
				outBytes.writeFloat(Util.getFloat(gltfData, texAcc, i, 0));
				outBytes.writeFloat(Util.getFloat(gltfData, texAcc, i, 1));
			} else {
				outBytes.writeFloat(0.5);
				outBytes.writeFloat(0.5);
			}
		}


		for( i in 0...index.vidx.length ) {
			var vidx = index.vidx[i];
			m.buffer[out++] = verts[vidx*3];
			m.buffer[out++] = verts[vidx*3+1];
			m.buffer[out++] = verts[vidx*3+2];

			m.buffer[out++] = normals[i*3];
			m.buffer[out++] = normals[i*3+1];
			m.buffer[out++] = normals[i*3+2];
			var uidx = uvs[0].index[i];

			m.buffer[out++] = uvs[0].values[uidx*2];
			m.buffer[out++] = uvs[0].values[uidx*2+1];

			m.tangents[i<<2] = 1;

			m.indexes[i] = i;
		}

		m.compute();
		return m.tangents;
		#elseif (sys || nodejs)
		var tmp = Sys.getEnv("TMPDIR");
		if( tmp == null ) tmp = Sys.getEnv("TMP");
		if( tmp == null ) tmp = Sys.getEnv("TEMP");
		if( tmp == null ) tmp = ".";
		var fileName = tmp+"/mikktspace_data"+Date.now().getTime()+"_"+Std.random(0x1000000)+".bin";
		var outFile = fileName+".out";
		var outputData = new haxe.io.BytesBuffer();
		outputData.addInt32(index.vidx.length);
		outputData.addInt32(8);
		outputData.addInt32(0);
		outputData.addInt32(3);
		outputData.addInt32(6);
		for( i in 0...index.vidx.length ) {
			inline function w(v:Float) outputData.addFloat(v);
			var vidx = index.vidx[i];
			w(verts[vidx*3]);
			w(verts[vidx*3+1]);
			w(verts[vidx*3+2]);

			w(normals[i*3]);
			w(normals[i*3+1]);
			w(normals[i*3+2]);
			var uidx = uvs[0].index[i];

			w(uvs[0].values[uidx*2]);
			w(uvs[0].values[uidx*2+1]);
		}
		outputData.addInt32(index.vidx.length);
		for( i in 0...index.vidx.length )
			outputData.addInt32(i);
		sys.io.File.saveBytes(fileName, outputData.getBytes());
		var ret = try Sys.command("mikktspace",[fileName,outFile]) catch( e : Dynamic ) -1;
		if( ret != 0 ) {
			sys.FileSystem.deleteFile(fileName);
			throw "Failed to call 'mikktspace' executable required to generate tangent data. Please ensure it's in your PATH";
		}
		var bytes = sys.io.File.getBytes(outFile);
		var arr = [];
		for( i in 0...index.vidx.length*4 )
			arr[i] = bytes.getFloat(i << 2);
		sys.FileSystem.deleteFile(fileName);
		sys.FileSystem.deleteFile(outFile);
		return arr;
		#else
		throw "Tangent generation is not supported on this platform";
		return ([] : Array<Float>);
		#end
		*/
		return null;
	}


	public static function emitHMD(name:String, relDir:String, data: Data) {
		var out = new HMDOut(name, relDir,data);
		return out.toHMD();
	}
}
