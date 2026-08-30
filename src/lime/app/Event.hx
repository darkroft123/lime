package lime.app;

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
class Event<T>
{
	public var canceled(default, null):Bool;

	@:noCompletion @:dox(hide) public var __listeners:Array<T>;
	@:noCompletion @:dox(hide) public var __repeat:Array<Bool>;

	@:noCompletion private var __priorities:Array<Int>;

	public var dispatch:Dynamic;

	public function new()
	{
		#if !macro
		canceled = false;
		__listeners = new Array();
		__priorities = new Array<Int>();
		__repeat = new Array<Bool>();
		dispatch = function(_) {}
		#end
	}

	public function add(listener:T, once:Bool = false, priority:Int = 0):Void
	{
		#if !macro
		for (i in 0...__priorities.length)
		{
			if (priority > __priorities[i])
			{
				__listeners.insert(i, cast listener);
				__priorities.insert(i, priority);
				__repeat.insert(i, !once);
				return;
			}
		}

		__listeners.push(cast listener);
		__priorities.push(priority);
		__repeat.push(!once);
		#end
	}

	public function cancel():Void
	{
		canceled = true;
	}

	public function has(listener:T):Bool
	{
		#if !macro
		for (l in __listeners)
		{
			if (Reflect.compareMethods(l, listener)) return true;
		}
		#end

		return false;
	}

	public function remove(listener:T):Void
	{
		#if !macro
		var i = __listeners.length;

		while (--i >= 0)
		{
			if (Reflect.compareMethods(__listeners[i], listener))
			{
				__listeners.splice(i, 1);
				__priorities.splice(i, 1);
				__repeat.splice(i, 1);
			}
		}
		#end
	}

	public function removeAll():Void
	{
		#if !macro
		var len = __listeners.length;

		__listeners.splice(0, len);
		__priorities.splice(0, len);
		__repeat.splice(0, len);
		#end
	}
}
