package cerastes.c2d.path;




// The Graph class remains unchanged
class Graph {
    public var nodes:Map<Int, Node>;

    public function new() {
        nodes = new Map<Int, Node>();
    }

    public function addNode(node:Node) {
        nodes.set(node.id, node);
    }

    public function addEdge(from:Int, to:Int) {
        nodes.get(from).neighbors.push(nodes.get(to));
        nodes.get(to).neighbors.push(nodes.get(from));
    }
}