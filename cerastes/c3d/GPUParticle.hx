package cerastes.c3d;

import h2d.Particles.ParticleGroup;
import h3d.parts.GpuParticles;
import h3d.parts.Emitter;
import h3d.parts.GpuParticles.GpuEmitMode;
import h3d.parts.GpuParticles.GpuSortMode;
import h3d.scene.Object;



@:structInit
class GPUParticleDef
{

	public var texture: String = null;
	public var colorGradient: String = null;

	public var sortMode: GpuSortMode = None;

	public var amount: Float = 1;
	public var nparts: Int = 100;
	public var emitMode: GpuEmitMode = Point;
	public var emitStartDist: Float = 0;
	public var emitDist: Float = 0;
	public var emitAngle: Float = 0;
	public var emitSync: Float = 0;
	public var emitDelay: Float = 0;
	public var emitOnBorder: Bool = false;

	public var clipBounds: Bool = false;
	public var transform3d: Bool = false;

	public var size: Float = 1;
	public var sizeIncr: Float = 0;
	public var sizeRand: Float = 0;

	public var life: Float = 1;
	public var lifeRand: Float = 0;

	public var speed: Float = 1;
	public var speedRand: Float = 0;
	public var speedIncr: Float = 0;
	public var gravity: Float = 0;

	public var rot: Float = 0;
	public var rotSpeed: Float = 0;
	public var rotSpeedRand: Float = 0;

	public var fadeIn: Float = 0.2;
	public var fadeOut: Float = 0.8;
	public var fadePower: Float = 1;

	public var frameCount: Int = 0;
	public var frameCountX: Int = 1;
	public var frameCountY: Int = 1;
	public var animationRepeat: Float = 1;

	public function addToEmitter( emitter: GpuParticles )
	{
		var g: GpuPartGroup = emitter.addGroup();

		if( texture != null ) g.texture = Utils.resolveTexture( texture );
		if( colorGradient != null && colorGradient.length > 0 ) g.colorGradient = Utils.resolveTexture( colorGradient );

		g.amount = amount;
		g.sortMode = sortMode;
		g.nparts = nparts;
		g.emitMode = emitMode;
		g.emitAngle = emitAngle;
		g.emitSync = emitSync;
		g.emitDelay = emitDelay;
		g.emitOnBorder = emitOnBorder;
		g.clipBounds = clipBounds;
		g.transform3D = transform3d;
		g.size = size;
		g.sizeIncr = sizeIncr;
		g.sizeRand = sizeRand;

		g.life = life;
		g.lifeRand = lifeRand;

		g.speed = speed;
		g.speedRand = speedRand;
		g.speedIncr = speedIncr;
		g.gravity = gravity;

		g.rotInit = rot;
		g.rotSpeed = rotSpeed;
		g.rotSpeedRand = rotSpeedRand;

		g.fadeIn = fadeIn;
		g.fadeOut = fadeOut;
		g.fadePower = fadePower;

		g.frameCount = frameCount;
		g.frameDivisionX = frameCountX;
		g.frameDivisionY = frameCountY;
		g.animationRepeat = animationRepeat;
	}
}