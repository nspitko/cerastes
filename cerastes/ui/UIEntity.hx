package cerastes.ui;

class UIEntity extends h2d.Object implements Entity
{
	public var lookupId: String;

	#if tools
	public static function getEditorIcon()
	{
		return "\uf07c";
	}
	#end

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
}