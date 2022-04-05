package cerastes.ui;

import cerastes.fmt.CUIResource;
import h2d.Object;

@:keep
class Reference extends h2d.Object
{

	var fileName: String;

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
		hxd.Res.loader.loadCache( file, CUIResource ).toObject(this);
	}

	public function reload()
	{
		removeChildren();
		load(fileName);
	}
}