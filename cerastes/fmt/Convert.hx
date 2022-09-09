package cerastes.fmt;

@:keep
class ConvertGLTF2HMD extends hxd.fs.Convert
{
	var parseFunc : (String, String, haxe.io.Bytes)->cerastes.fmt.gltf.Data;
	public function new(binary: Bool) {
		this.parseFunc = binary ?
			cerastes.fmt.gltf.Parser.parseGLB :
			cerastes.fmt.gltf.Parser.parseGLTF;

		super(binary?"glb":"gltf", "hmd");
	}

	override function convert() {

		var splitPath = srcPath.split("/");
		var name = splitPath[splitPath.length - 1];

		var localPath = srcPath.substr(0, srcPath.length-name.length);

		var relPath = "";
		// Find the path relative to the assets dir

		var resPos = localPath.indexOf("/res/");

		if (resPos != -1) {
			relPath = localPath.substr(resPos+4);
			trace(relPath);
		}
		try {
			var gltfData = parseFunc(name, localPath, srcBytes);
			var hmd = cerastes.fmt.gltf.HMDOut.emitHMD(name, relPath, gltfData);
			var out = new haxe.io.BytesOutput();
			new hxd.fmt.hmd.Writer(out).write(hmd);
			save(out.getBytes());
		}
		catch( e : Dynamic ) throw Std.string(e) + " in " + srcPath;

	}

	static var glbConv = hxd.fs.Convert.register(new ConvertGLTF2HMD(true));
	static var gltfConv = hxd.fs.Convert.register(new ConvertGLTF2HMD(false));

}
