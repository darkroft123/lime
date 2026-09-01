package lime.utils;

import lime.media.AudioBuffer;
import lime.graphics.Image;

/**
	AssetCache de Lime con LRU para Dark's Collection.
	Sobreescribe el AssetCache estandar de Lime.

	Maneja el cache de imagenes y audio con eviction automatica.
**/
class AssetCache
{
	public var audio:Map<String, AudioBuffer>;
	public var enabled:Bool = true;
	public var image:Map<String, Image>;
	public var font:Map<String, Dynamic>;
	public var version:Int;

	/**
		Maximo de memoria en bytes para imagenes.
		128MB por defecto. Pon 0 para desactivar.
	**/
	public var maxImageMemoryBytes:Int;

	// LRU para imagenes
	@:noCompletion private var __imageLRU:Array<String>;
	@:noCompletion private var __currentImageMemory:Int;

	public function new()
	{
		audio = new Map<String, AudioBuffer>();
		font = new Map<String, Dynamic>();
		image = new Map<String, Image>();
		__imageLRU = [];
		__currentImageMemory = 0;
		maxImageMemoryBytes = 128 * 1024 * 1024; // 128MB

		#if (macro || commonjs || lime_disable_assets_version)
		version = 0;
		#elseif lime_assets_version
		version = Std.parseInt(haxe.macro.Compiler.getDefine("lime-assets-version"));
		#else
		version = 1;
		#end
	}

	public function exists(id:String, ?type:AssetType):Bool
	{
		if (type == AssetType.IMAGE || type == null)
		{
			if (image.exists(id)) return true;
		}

		if (type == AssetType.FONT || type == null)
		{
			if (font.exists(id)) return true;
		}

		if (type == AssetType.SOUND || type == AssetType.MUSIC || type == null)
		{
			if (audio.exists(id)) return true;
		}

		return false;
	}

	/**
		Obtiene una imagen del cache y la marca como usada (LRU).
	**/
	public function getImage(id:String):Image
	{
		var img = image.get(id);
		if (img != null)
		{
			__touchImageLRU(id);
		}
		return img;
	}

	public function set(id:String, type:AssetType, asset:Dynamic):Void
	{
		switch (type)
		{
			case FONT:
				font.set(id, asset);

			case IMAGE:
				if (!(asset is Image)) throw "Cannot cache non-Image asset: " + asset + " as Image";

				// Si ya existia, restar memoria vieja
				if (image.exists(id))
				{
					var old = image.get(id);
					if (old != null)
					{
						__currentImageMemory -= __estimateImageSize(old);
					}
					__removeFromImageLRU(id);
				}

				image.set(id, asset);
				__currentImageMemory += __estimateImageSize(asset);
				__imageLRU.push(id);

				// Evict si se supera el limite
				if (maxImageMemoryBytes > 0)
				{
					while (__currentImageMemory > maxImageMemoryBytes && __imageLRU.length > 0)
					{
						__evictOldestImage();
					}
				}

			case SOUND, MUSIC:
				if (!(asset is AudioBuffer)) throw "Cannot cache non-AudioBuffer asset: " + asset + " as AudioBuffer";
				audio.set(id, asset);

			default:
				throw type + " assets are not cachable";
		}
	}

	public function clear(prefix:String = null):Void
	{
		if (prefix == null)
		{
			audio = new Map<String, AudioBuffer>();
			font = new Map<String, Dynamic>();
			image = new Map<String, Image>();
			__imageLRU = [];
			__currentImageMemory = 0;
		}
		else
		{
			var keys = audio.keys();
			for (key in keys)
			{
				if (StringTools.startsWith(key, prefix))
				{
					audio.remove(key);
				}
			}

			var keys = font.keys();
			for (key in keys)
			{
				if (StringTools.startsWith(key, prefix))
				{
					font.remove(key);
				}
			}

			var keys = image.keys();
			for (key in keys)
			{
				if (StringTools.startsWith(key, prefix))
				{
					__removeImage(key);
				}
			}
		}
	}

	/**
		Elimina una imagen del cache y actualiza contadores.
	**/
	private function __removeImage(id:String):Void
	{
		if (image.exists(id))
		{
			var img = image.get(id);
			if (img != null)
			{
				__currentImageMemory -= __estimateImageSize(img);
			}
			__removeFromImageLRU(id);
			image.remove(id);
		}
	}

	private function __estimateImageSize(img:Image):Int
	{
		if (img == null || img.buffer == null) return 0;
		return img.width * img.height * 4;
	}

	private function __touchImageLRU(id:String):Void
	{
		__removeFromImageLRU(id);
		__imageLRU.push(id);
	}

	private function __removeFromImageLRU(id:String):Void
	{
		var idx = __imageLRU.indexOf(id);
		if (idx >= 0)
		{
			__imageLRU.splice(idx, 1);
		}
	}

	private function __evictOldestImage():Void
	{
		if (__imageLRU.length == 0) return;

		var oldestId = __imageLRU.shift();
		if (oldestId != null && image.exists(oldestId))
		{
			var img = image.get(oldestId);
			if (img != null)
			{
				__currentImageMemory -= __estimateImageSize(img);
			}
			image.remove(oldestId);
		}
	}

	/**
		Obtiene la memoria actual usada por imagenes en bytes.
	**/
	public function getCurrentImageMemory():Int
	{
		return __currentImageMemory;
	}
}
