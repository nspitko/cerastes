package cerastes.types;

class List<T>
{
	private var head:ListNode<T>;
	private var tail:ListNode<T>;

	public var length(default, null):Int;

	public function new()
	{
		length = 0;
	}

	public function add(item:T)
	{
		var x = ListNode.create(item, null);
		if (head == null)
			head = x;
		else
			tail.next = x;
		tail = x;

		length++;
	}

	public function insert( item: T, check: (T, T) -> Bool )
	{
		if( head == null || check( item, head.item ) )
		{
			push(item);
			return;
		}
		var prev:ListNode<T> = null;
		var l = head;


		while (l != null)
		{
			if ( check(item, l.item) )
			{
				var v = ListNode.create(item, prev.next );
				prev.next = l;

				length++;
				return ;
			}
			prev = l;
			l = l.next;
		}

		add(item);

	}

	public function push(item:T)
	{
		var x = ListNode.create(item, head);
		head = x;

		if (tail == null)
			tail = x;

		length++;
	}

	public function first():Null<ListNode<T>>
	{
		return head;
	}

	public function last():Null<ListNode<T>>
	{
		return tail;
	}

	public function pop():Null<ListNode<T>>
	{
		if (head == null)
			return null;

		var x = head;
		head = head.next;

		if (head == null)
			tail = null;

		length--;

		return x;
	}

	public function isEmpty():Bool
	{
		return (head == null);
	}

	public function clear():Void
	{
		head = null;
		tail = null;
		length = 0;
	}

	public function remove(value:T):Bool
	{
		var prev:ListNode<T> = null;
		var l = head;
		while (l != null)
		{
			if (l.item == value)
			{
				if (prev == null)
					head = l.next;
				else
					prev.next = l.next;

				if (tail.item == value)
					tail = prev;

				length--;
				return true;
			}
			prev = l;
			l = l.next;
		}

		return false;
	}

	/**
	 Returns an iterator on the elements of the list.
	**/
	public inline function iterator():ListIterator<T>
	{
		return new ListIterator<T>(head);
	}

	/**
	 Returns an iterator of the List indices and values.
	**/
	@:pure @:runtime public inline function keyValueIterator():ListKeyValueIterator<T>
	{
		return new ListKeyValueIterator(head);
	}

	/**
	 Returns a string representation of `this` List.

		The result is enclosed in { } with the individual elements being
		separated by a comma.
	**/
	public function toString()
	{
		var s = new StringBuf();
		var first = true;
		var l = head;
		s.add("{");
		while (l != null) {
			if (first)
				first = false;
			else
				s.add(", ");
			s.add(Std.string(l.item));
			l = l.next;
		}
		s.add("}");
		return s.toString();
	}

	/**
	 Returns a string representation of `this` List, with `sep` separating
		each element.
	**/
	public function join(sep:String)
	{
		var s = new StringBuf();
		var first = true;
		var l = head;
		while (l != null) {
			if (first)
				first = false;
			else
				s.add(sep);
			s.add(l.item);
			l = l.next;
		}
		return s.toString();
	}

	/**
	 Returns a list filtered with `f`. The returned list will contain all
		elements for which `f(x) == true`.
	**/
	public function filter(f:T->Bool)
	{
		var l2 = new List();
		var l = head;
		while (l != null) {
			var v = l.item;
			l = l.next;
			if (f(v))
				l2.add(v);
		}
		return l2;
	}

	/**
	 Returns a new list where all elements have been converted by the
		function `f`.
	**/
	public function map<X>(f:T->X):List<X>
	{
		var b = new List();
		var l = head;
		while (l != null) {
			var v = l.item;
			l = l.next;
			b.add(f(v));
		}
		return b;
	}
}

private class ListNode<T>
{
	public var item:T;
	public var next:ListNode<T>;

	public function new(item:T, next:ListNode<T>) {
		this.item = item;
		this.next = next;
	}

	extern public inline static function create<T>(item:T, next:ListNode<T>):ListNode<T> {
		return new ListNode(item, next);
	}
}

private class ListIterator<T>
{
	var head:ListNode<T>;

	public inline function new(head:ListNode<T>) {
		this.head = head;
	}

	public inline function hasNext():Bool {
		return head != null;
	}

	public inline function next():T {
		var val = head.item;
		head = head.next;
		return val;
	}
}

private class ListKeyValueIterator<T>
{
	var idx:Int;
	var head:ListNode<T>;

	public inline function new(head:ListNode<T>) {
		this.head = head;
		this.idx = 0;
	}

	public inline function hasNext():Bool {
		return head != null;
	}

	public inline function next():{key:Int, value:T} {
		var val = head.item;
		head = head.next;
		return {value: val, key: idx++};
	}
}
