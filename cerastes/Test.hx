package cerastes;

@:structInit class UnitTest
{
	public var name: String;
	public var func: UnitTest -> Bool;
}

class Test
{
	static var tests: Array<UnitTest> = [];

	public static function run( ?test: String )
	{
		for(t in tests )
		{
			if( test == null || t.name == test )
				runSingle(t);
		}
	}

	static function runSingle( t: UnitTest )
	{
		Utils.info('Beginning test: ${ t.name }');

		if( !t.func( t ) )
			Utils.warning('Test ${t.name} failed!!!');
		else
			Utils.info('Test Passed.');

	}


	public static var success = true;
	public static var testName: String = "???";

	static function begin( t: UnitTest )
	{

		success = true;
		testName = t.name;

	}

	static function fail(msg: String)
	{

		cerastes.Utils.error('${testName}: ${msg}');
		success = false;

	}
}