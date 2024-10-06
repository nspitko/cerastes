package cerastes.ui;

import cerastes.fmt.CUIResource;
import h2d.Object;

@:keep
class Reference extends h2d.Object
{

	var fileName: String;
	var ref: h2d.Object;
	var def: CUIObject;
	var preview: Bool  = false;

	public function new( ?fileName: String, ?def: CUIObject, ?parent: Object, ?preview: Bool )
	{
		super(parent);
		this.def = def;

		this.preview = preview;

		//if( fileName != null )
		//	load( fileName, def );
	}

	public function load( file: String, def: CUIObject = null )
	{

		removeChildren();
		fileName = file;
		#if tools
		var res = hxd.Res.loader.load( file );

		ref = res.to(CUIResource).toObject(this, preview, def);
		res.watch(() -> {
			@:privateAccess res.to(CUIResource).data = null;
			reload();
		});
		#else
		ref = hxd.Res.loader.loadCache( file, CUIResource ).toObject(this);
		#end
	}

	public function reload()
	{
		load(fileName, def);
	}

	public function get()
	{
		return ref;
	}

	/**
	 * Creates an instance of the reference target. This does NOT clone the reference!
	 * This is used when we want to use a reference as a template.
	 */
	public function make( ?parent: Object )
	{
		var ref = hxd.Res.loader.loadCache( fileName, CUIResource ).toObject( parent );
		return ref;
	}

	public override function addChild( s : Object ) : Void {
		// If we have the special _children field, add it there, else do the usual
		var cr = getObjectByName("_children");
		if( cr != null )
			cr.addChild(s);
		else
			super.addChild(s);
	}
}