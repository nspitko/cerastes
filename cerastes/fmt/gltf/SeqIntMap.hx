package cerastes.fmt.gltf;

import cerastes.Utils as Debug;

typedef MapVal = { ints:Array<Int>, index:Int};

class SeqIntMap {

    var map: Map<Int, MapVal >;
    var invMap: Array<Int>;
    var hits = 0;
    var misses = 0;
    var colls = 0;

    public var count(get, never): Int;

    static final primeList = [13,29,41,59,73,101,113];

    public function new() {
        map = new Map();
        invMap = [];
    }

    static inline function hashList(ints: Array<Int>) {
        // If this assert triggers, add more primes to the list
        Debug.assert(ints.length <= primeList.length);
        var hash = 0;
        for (i in 0...ints.length) {
            hash += ints[i] * primeList[i];
        }
        return hash;
    }
    inline function listSame(a: Array<Int>, b: Array<Int>) {
        var res = true;
        if (a.length != b.length) res = false;
        else {
            for (i in 0...a.length) {
                if (a[i] != b[i]) {
                    res = false;
                    break;
                }
            }
        }
        return res;
    }

    public function add(ints: Array<Int>): Int {
        var pos = hashList(ints);
        while (true) {
            var val = map[pos];
            if (val == null) {
                var ind = invMap.length;
                map[pos] = {ints:ints, index:ind};
                invMap.push(pos);
                misses++;
                return ind;
            }
            if (listSame(ints, val.ints)) {
                hits++;
                return val.index;
            }
            colls++;
            pos++;
        }
        Debug.assert(false, "Logic Error");
        return -1;
     }
     public function get_count() {
         return invMap.length;
     }
     // reverse of 'add' function
     public function getList(ind:Int): Array<Int> {
         Debug.assert(ind < invMap.length);
         var pos = invMap[ind];
         return map[pos].ints;
     }

     public function debugInfo() {
         trace('Hits: $hits Misses: $misses Collision: $colls');
     }
}
