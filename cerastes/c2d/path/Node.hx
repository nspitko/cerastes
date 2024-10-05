package cerastes.c2d.path;

// Update the Node class to include the 'f' value
class Node {
    public var id:Int;
    public var x:Float;
    public var y:Float;
    public var neighbors:Array<Node>;
    public var f:Float; // f-score for A* algorithm

    static var nextId = 0;
    public function new(x:Float, y:Float) {
        this.id = nextId++;
        this.x = x;
        this.y = y;
        this.neighbors = [];
        this.f = 0;
    }
}