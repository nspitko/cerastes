package cerastes.c3d.entities;

#if q3bsp
class Brush extends cerastes.c3d.q3bsp.Q3BSPBrush {}
#else #if q3map
class Brush extends cerastes.c3d.map.QBrush {}
#else
class Brush extends BaseBrush {}
#end #end

class BaseBrush extends Entity
{

}

