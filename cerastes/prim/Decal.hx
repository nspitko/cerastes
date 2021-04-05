package cerastes.prim;
import h3d.scene.fwd.Renderer.DepthPass;
import h3d.shader.pbr.VolumeDecal.DecalPBR;
import h3d.mat.Material;
import h3d.shader.BaseMesh;
import h3d.shader.Texture;
import hxsl.ShaderList;
import h3d.mat.Pass;
import hxsl.Shader;
import h3d.mat.Defaults;
import h3d.col.Point;
import h3d.col.Bounds;
import h3d.scene.*;

class Decal extends Mesh {

	public static function makeDecal( texture: h3d.mat.Texture )
	{
		var cube = h3d.prim.Cube.defaultUnitCube();

		var mat = @:privateAccess new h3d.mat.Material();
		mat.texture = texture;
		mat.props = mat.getDefaultProps();
		var d = new Decal(cube, mat );
		d.scale(0.9);

		return d;
	}

	public function new( primitive, material, ?parent ) {
		super(primitive, material, parent);

		
		#if pbr
		var shader = new h3d.shader.pbr.VolumeDecal.DecalOverlay();
		shader.colorTexture = hxd.Res.tex.select.toTexture();
		#else
		var shader = Defaults.makeVolumeDecal(primitive.getBounds());
		#end

		// Setup material
		//material.blendMode = Alpha;
		//material.mainPass.depth(false,Less);
		material.removePass( material.getPass("shadow")  );

		material.blendMode = Alpha;

		material.mainPass.removeShader( material.mainPass.getShader( h3d.shader.Shadow ) );
		
		material.mainPass.addShader(shader);
		

		
	}

	override function sync( ctx : RenderContext ) {
		super.sync(ctx);

		var shader = material.mainPass.getShader( h3d.shader.VolumeDecal );
		if( shader != null )
			syncDecal(shader);
	}

	function syncDecal( shader : h3d.shader.VolumeDecal ) {
		shader.normal = getAbsPos().up();
		shader.tangent = getAbsPos().right();
	}
}