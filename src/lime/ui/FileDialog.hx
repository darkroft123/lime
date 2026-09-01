package lime.ui;

import lime._internal.backend.native.NativeCFFI;
import lime.app.Event;
import lime.graphics.Image;
import lime.system.BackgroundWorker;
import lime.utils.Resource;
#if sys
import sys.io.File;
#end
#if (js && html5)
import js.html.Blob;
#end

#if !lime_debug
@:fileXml('tags="haxe,release"')
@:noDebug
#end
@:access(lime._internal.backend.native.NativeCFFI)
@:access(lime.graphics.Image)
class FileDialog
{
	public var onCancel = new Event<Void->Void>();
	public var onOpen = new Event<Resource->Void>();
	public var onSave = new Event<String->Void>();
	public var onSelect = new Event<String->Void>();
	public var onSelectMultiple = new Event<Array<String>->Void>();

	public function new() {}

	public function browse(type:FileDialogType = null, filter:String = null, defaultPath:String = null, title:String = null):Bool
	{
		if (type == null) type = FileDialogType.OPEN;

		#if desktop
		var worker = new BackgroundWorker();

		worker.doWork.add(function(_)
		{
			switch (type)
			{
				case OPEN:
					#if linux
					if (title == null) title = "Open File";
					#end
					var path:String = null;
					#if (!macro && lime_cffi)
					NativeCFFI.lime_file_dialog_open_file(null, title, null, null, null, 0, defaultPath != null ? defaultPath : "", true);
					#end
					worker.sendComplete(path);

				case OPEN_MULTIPLE:
					#if linux
					if (title == null) title = "Open Files";
					#end
					var paths:Array<String> = null;
					worker.sendComplete(paths);

				case OPEN_DIRECTORY:
					#if linux
					if (title == null) title = "Open Directory";
					#end
					var path:String = null;
					#if (!macro && lime_cffi)
					NativeCFFI.lime_file_dialog_open_directory(null, title, null, defaultPath != null ? defaultPath : "", true);
					#end
					worker.sendComplete(path);

				case SAVE:
					#if linux
					if (title == null) title = "Save File";
					#end
					var path:String = null;
					#if (!macro && lime_cffi)
					NativeCFFI.lime_file_dialog_save_file(null, title, null, null, null, 0, defaultPath != null ? defaultPath : "");
					#end
					worker.sendComplete(path);
			}
		});

		worker.onComplete.add(function(result)
		{
			switch (type)
			{
				case OPEN, OPEN_DIRECTORY, SAVE:
					var path:String = cast result;
					if (path != null)
					{
						if (type == SAVE && filter != null && path.indexOf(".") == -1) path += "." + filter;
						onSelect.dispatch(path);
					}
					else onCancel.dispatch();

				case OPEN_MULTIPLE:
					var paths:Array<String> = cast result;
					if (paths != null && paths.length > 0) onSelectMultiple.dispatch(paths);
					else onCancel.dispatch();
			}
		});

		worker.run();
		return true;
		#else
		onCancel.dispatch();
		return false;
		#end
	}

	public function open(filter:String = null, defaultPath:String = null, title:String = null):Bool
	{
		#if (desktop && sys)
		var worker = new BackgroundWorker();

		worker.doWork.add(function(_)
		{
			#if linux
			if (title == null) title = "Open File";
			#end
			var path:String = null;
			#if (!macro && lime_cffi)
			NativeCFFI.lime_file_dialog_open_file(null, title, null, null, null, 0, defaultPath != null ? defaultPath : "", false);
			#end
			worker.sendComplete(path);
		});

		worker.onComplete.add(function(path:String)
		{
			if (path != null)
			{
				try
				{
					var data = File.getBytes(path);
					onOpen.dispatch(data);
					return;
				}
				catch (e:Dynamic) {}
			}
			onCancel.dispatch();
		});

		worker.run();
		return true;
		#else
		onCancel.dispatch();
		return false;
		#end
	}

	public function save(data:Resource, filter:String = null, defaultPath:String = null, title:String = null, type:String = "application/octet-stream"):Bool
	{
		if (data == null) { onCancel.dispatch(); return false; }

		#if (desktop && sys)
		var worker = new BackgroundWorker();

		worker.doWork.add(function(_)
		{
			#if linux
			if (title == null) title = "Save File";
			#end
			var path:String = null;
			#if (!macro && lime_cffi)
			NativeCFFI.lime_file_dialog_save_file(null, title, null, null, null, 0, defaultPath != null ? defaultPath : "");
			#end
			worker.sendComplete(path);
		});

		worker.onComplete.add(function(path:String)
		{
			if (path != null)
			{
				try
				{
					File.saveBytes(path, data);
					onSave.dispatch(path);
					return;
				}
				catch (e:Dynamic) {}
			}
			onCancel.dispatch();
		});

		worker.run();
		return true;
		#elseif (js && html5)
		var defaultExtension = "";
		if (Image.__isPNG(data)) { type = "image/png"; defaultExtension = ".png"; }
		else if (Image.__isJPG(data)) { type = "image/jpeg"; defaultExtension = ".jpg"; }
		else if (Image.__isGIF(data)) { type = "image/gif"; defaultExtension = ".gif"; }
		else if (Image.__isWebP(data)) { type = "image/webp"; defaultExtension = ".webp"; }

		var path = defaultPath != null ? haxe.io.Path.withoutDirectory(defaultPath) : "download" + defaultExtension;
		var buffer = (data : haxe.io.Bytes).getData();
		buffer = buffer.slice(0, (data : haxe.io.Bytes).length);
		#if commonjs
		untyped #if haxe4 js.Syntax.code #else __js__ #end ("require ('file-saver')")(new Blob([buffer], {type: type}), path, true);
		#else
		untyped window.saveAs(new Blob([buffer], {type: type}), path, true);
		#end
		onSave.dispatch(path);
		return true;
		#else
		onCancel.dispatch();
		return false;
		#end
	}
}
