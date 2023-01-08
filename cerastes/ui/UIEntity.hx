package cerastes.ui;

import h2d.Object;
import cerastes.Entity.EntityManager;

class UIEntity extends h2d.Object implements Entity
{
	public var lookupId: String;

	#if tools
	public static function getEditorIcon()
	{
		return "\uf07c";
	}
	#end

	public function new()
	{
		super();
	}


	public function tick( delta: Float ) {}
	public function destroy()
	{
		removeChildren();
		visible = false;
	}

	public function isDestroyed()
	{
		return false;
	}

	//

	public function initialize( root: h2d.Object )
	{

	}

	public override function onAdd()
	{
		super.onAdd();
		EntityManager.instance.register(this);
	}

	public override function onRemove()
	{
		super.onRemove();
		EntityManager.instance.remove(this);
	}

}