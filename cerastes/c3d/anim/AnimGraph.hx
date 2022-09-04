package cerastes.c3d.anim;


class AnimGraph
{
	var data: Map<String,Float>;

	public function set( name: String, val: Float )
	{
		if( Utils.assert(data.exists( name ), 'Tried to write invalid graph var ${name}' ) )
			return;

		state[name] = val;
	}

	public function get( name )
	{
		if( Utils.assert(data.exists( name ), 'Tried to read invalid graph var ${name}' ) )
			return 0;

		return data.get(name);
	}
}