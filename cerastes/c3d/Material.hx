package cerastes.c3d;

import h3d.mat.MaterialDatabase;
import h3d.shader.pbr.PropsValues;
import hl.UI;
import cerastes.data.Nodes.NodeDefinition;
import cerastes.data.Nodes.Link;
import cerastes.data.Nodes.Node;
import h3d.mat.PbrMaterial;
import h3d.mat.PbrMaterial.PbrProps;
import h3d.mat.PbrMaterial.PbrStencilOp;
import h3d.mat.PbrMaterial.PbrStencilCompare;
import h3d.mat.PbrMaterial.PbrDepthWrite;
import h3d.mat.PbrMaterial.PbrDepthTest;
import h3d.mat.PbrMaterial.PbrMode;
import h3d.mat.PbrMaterial.PbrBlend;
import h3d.mat.PbrMaterial.PbrCullingMode;

import cerastes.Utils;

@:structInit
class MaterialDef
{
	public var version: Int = 1;
	// PBR
	public var metalness: Float = 0;
	public var roughness: Float = 1;
	public var occlusion: Float = 1;
	public var emissive: Float = 0;

	// Props
	public var mode: PbrMode = PBR;
	public var blend: PbrBlend = None;
	public var shadows: Bool = true;
	public var culling: PbrCullingMode = Back;
	public var depthTest: PbrDepthTest = Less;
	public var depthWrite: PbrDepthWrite = Default;
	public var colorMask: Int = 1 << 0 | 1 << 1 | 1 << 2 | 1 << 3;
	public var alphaKill: Bool = true;
	public var parallax: Float = 0;
	public var textureWrap: Bool = true;

	public var enableStencil: Bool = false;
	public var stencilCompare: PbrStencilCompare = Always;
	public var stencilPassOp: PbrStencilOp = Keep;
	public var stencilFailOp: PbrStencilOp = Keep;
	public var depthFailOp: PbrStencilOp = Keep;
	public var stencilValue: Int = 0;
	public var stencilWriteMask: Int = 0;
	public var stencilReadMask: Int = 0;

	public var drawOrder: String = "0";

	// Textures
	public var albedo: String = "#FF00FF";
	public var normal: String = null;
	public var pbr: String = null;

	// Allow up to 3 additional utility slots. God help us if we ever need more than 3.
	public var utilA: String = null;
	public var utilB: String = null;
	public var utilC: String = null;

	public function toMaterial()
	{
		var tex = Utils.resolveTexture( albedo );
		var mat = @:privateAccess new PbrMaterial( tex );
		mat.props = getProps();

		mat.mainPass.enableLights = true;

		if( normal != null )
		{
			mat.normalMap = Utils.resolveTexture( normal );
			mat.normalMap.wrap = textureWrap ? Repeat : Clamp;
		}

		// If we have a pbr map, use that.
		if( pbr != null )
		{
			var props = mat.mainPass.getShader( h3d.shader.pbr.PropsTexture );
			if( props == null )
			{
				props = new h3d.shader.pbr.PropsTexture( Utils.resolveTexture( pbr ) );
				mat.mainPass.addShader( props );
			}
			else
			{
				props.texture = Utils.resolveTexture( pbr );
			}

			props.texture.wrap = textureWrap ? Repeat : Clamp;
			props.emissiveValue = emissive;

			var oldProps = mat.mainPass.getShader( h3d.shader.pbr.PropsValues );
			if( oldProps != null )
				mat.mainPass.removeShader( oldProps );
		}
		else
		{
			// Else use fixed value props.
			var props = mat.mainPass.getShader( h3d.shader.pbr.PropsValues );
			if( props == null )
			{
				props = new h3d.shader.pbr.PropsValues( metalness, roughness, occlusion, emissive );
				mat.mainPass.addShader( props );
			}
			else
			{
				props.metalnessValue = metalness;
				props.roughnessValue = roughness;
				props.occlusionValue = occlusion;
				props.emissiveValue = emissive;
			}

			var oldProps = mat.mainPass.getShader( h3d.shader.pbr.PropsTexture );
			if( oldProps != null )
				mat.mainPass.removeShader( oldProps );
		}
		return mat;
	}

	public function getProps() : Any
	{
		var props : PbrProps = {
			mode : mode != null ? mode : PBR,
			blend : blend != null ? blend : None,
			shadows : shadows,
			culling : culling != null ? culling : Back,
			depthTest : depthTest != null ? depthTest : Less,
			colorMask : colorMask,
			enableStencil : enableStencil,
		};

		// Optionals
		if( depthWrite != null )
			props.depthWrite = depthWrite;

		if( alphaKill )
			props.alphaKill = alphaKill;

		if( emissive != 0 )
			props.emissive = emissive;

		if( parallax != 0 )
			props.parallax = parallax;

		if( textureWrap )
			props.textureWrap = textureWrap;

		// @todo: optional stencil ops

		return props;
	}

	public static function loadMaterial( file: String )
	{
		if( file == null || !hxd.Res.loader.exists( file ))
		{
			var mat: MaterialDef = {};
			return mat.toMaterial();
		}

		// If it's not a material, load the texture and jam it into the default material
		if( !StringTools.endsWith(file, ".material") )
		{
			var mat: MaterialDef = {};
			mat.albedo = file;
			return mat.toMaterial();
		}

		var mat: MaterialDef = cerastes.file.CDParser.parse( hxd.Res.loader.load(file).entry.getText(), MaterialDef );
		return mat.toMaterial();
	}
}