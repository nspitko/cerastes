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
		ref = hxd.Res.loader.loadCache( file, CUIResource ).toObject(this);
	}

	public function reload()
	{
		removeChildren();
		load(fileName);
	}

	public function get()
	{
		return ref;
	}
}