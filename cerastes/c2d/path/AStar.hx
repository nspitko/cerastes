package cerastes.c2d.path;

class PriorityQueue<T> {
    private var heap:Array<T>;
    private var compare:(T, T) -> Int;

    public function new(compare:(T, T) -> Int) {
        this.heap = [];
        this.compare = compare;
    }

    public function enqueue(item:T) {
        heap.push(item);
        bubbleUp(heap.length - 1);
    }

    public function dequeue():Null<T> {
        if (heap.length == 0) return null;
        if (heap.length == 1) return heap.pop();

        var item = heap[0];
        heap[0] = heap.pop();
        bubbleDown(0);
        return item;
    }

    private function bubbleUp(index:Int) {
        while (index > 0) {
            var parentIndex = Std.int((index - 1) / 2);
            if (compare(heap[index], heap[parentIndex]) >= 0) break;
            swap(index, parentIndex);
            index = parentIndex;
        }
    }

    public function contains(item:T):Bool {
        for (element in heap) {
            if (compare(element, item) == 0) {
                return true;
            }
        }
        return false;
    }

    private function bubbleDown(index:Int) {
        while (true) {
            var leftChild = 2 * index + 1;
            var rightChild = 2 * index + 2;
            var smallest = index;

            if (leftChild < heap.length && compare(heap[leftChild], heap[smallest]) < 0) {
                smallest = leftChild;
            }
            if (rightChild < heap.length && compare(heap[rightChild], heap[smallest]) < 0) {
                smallest = rightChild;
            }

            if (smallest == index) break;
            swap(index, smallest);
            index = smallest;
        }
    }

    private function swap(i:Int, j:Int) {
        var temp = heap[i];
        heap[i] = heap[j];
        heap[j] = temp;
    }

    public function isEmpty():Bool {
        return heap.length == 0;
    }
}

class AStar {
    private static function heuristic(a:Node, b:Node):Float {
        return Math.sqrt(Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2));
    }

    public static function findPath(graph:Graph, start:Int, goal:Int):Array<Node> {
        var openSet = new PriorityQueue<Node>((a, b) -> Std.int((a.f - b.f) * 1000)); // Multiply by 1000 to handle float comparison
        var cameFrom = new Map<Int, Node>();
        var gScore = new Map<Int, Float>();
        var fScore = new Map<Int, Float>();

        var startNode = graph.nodes.get(start);
        var goalNode = graph.nodes.get(goal);

        startNode.f = heuristic(startNode, goalNode);
        openSet.enqueue(startNode);
        gScore.set(start, 0);
        fScore.set(start, startNode.f);

        while (!openSet.isEmpty()) {
            var current = openSet.dequeue();

            if (current.id == goal) {
                return reconstructPath(cameFrom, current);
            }

            for (neighbor in current.neighbors) {
                var tentativeGScore = gScore.get(current.id) + heuristic(current, neighbor);

                if (!gScore.exists(neighbor.id) || tentativeGScore < gScore.get(neighbor.id)) {
                    cameFrom.set(neighbor.id, current);
                    gScore.set(neighbor.id, tentativeGScore);
                    neighbor.f = gScore.get(neighbor.id) + heuristic(neighbor, goalNode);
                    fScore.set(neighbor.id, neighbor.f);

                    if (!openSet.contains(neighbor)) {
                        openSet.enqueue(neighbor);
                    }
                }
            }
        }

        return null; // No path found
    }

    private static function reconstructPath(cameFrom:Map<Int, Node>, current:Node):Array<Node> {
        var path = [current];
        while (cameFrom.exists(current.id)) {
            current = cameFrom.get(current.id);
            path.unshift(current);
        }
        return path;
    }
}
