package cerastes.ui;

import cerastes.fmt.CUIResource;
import h2d.Object;

@:keep
class Reference extends h2d.Object
{

	var fileName: String;
	var ref: h2d.Object;

	public function new( ?fileName: String, ?parent: Object )
	{
		super(parent);

		if( fileName != null )
			load( fileName );
	}

	public function load( file: String )
	{

		removeChildren();
		fileName = file;
		#if tools
		var res = hxd.Res.loader.load( file );
		ref = res.to(CUIResource).toObject(this);
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
		load(fileName);
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
}