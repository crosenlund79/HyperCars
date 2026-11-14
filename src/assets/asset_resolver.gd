class_name AssetResolver
extends RefCounted
## Single entry point for replaceable graphics (contract: assets/README.md).
##
## A logical name such as "cars/car_player" resolves to:
##   1. user override  <override_root>/graphics/cars/car_player.png
##   2. packaged fallback  res://assets/graphics/cars/template_car_player.png
## Missing or invalid overrides fall back with a warning. Results are cached for
## the session; override changes take effect after a game restart.

const GRAPHICS_DIR := "graphics"
const FALLBACK_ROOT := "res://assets/graphics"
## Supported override formats for graphics.
const GRAPHICS_EXTENSIONS: Array[String] = ["png"]

var override_root: String
var _cache: Dictionary = {}


func _init(p_override_root: String = "") -> void:
	if p_override_root.is_empty():
		override_root = compute_override_root(
			OS.has_feature("editor"),
			OS.get_executable_path(),
			ProjectSettings.globalize_path("res://custom"))
	else:
		override_root = p_override_root


## Editor/development: the project's custom/ folder. Exported game: custom/ next to the executable.
static func compute_override_root(is_editor: bool, executable_path: String, project_custom_dir: String) -> String:
	if is_editor:
		return project_custom_dir
	return executable_path.get_base_dir().path_join("custom")


func get_texture(logical_name: String) -> Texture2D:
	if _cache.has(logical_name):
		return _cache[logical_name]
	var texture := _load_override(logical_name)
	if texture == null:
		texture = _load_fallback(logical_name)
	_cache[logical_name] = texture
	return texture


func override_path(logical_name: String, extension: String = "png") -> String:
	return override_root.path_join(GRAPHICS_DIR).path_join(logical_name + "." + extension)


static func fallback_path(logical_name: String) -> String:
	var dir := logical_name.get_base_dir()
	var file := "template_" + logical_name.get_file() + ".png"
	return FALLBACK_ROOT.path_join(dir).path_join(file) if not dir.is_empty() else FALLBACK_ROOT.path_join(file)


func _load_override(logical_name: String) -> Texture2D:
	for extension in GRAPHICS_EXTENSIONS:
		var path := override_path(logical_name, extension)
		if not FileAccess.file_exists(path):
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		var image := Image.new()
		var err := ERR_FILE_CORRUPT
		if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
			err = image.load_png_from_buffer(bytes)
		if err != OK or image.is_empty():
			push_warning("AssetResolver: invalid override '%s' (error %d); using template." % [path, err])
			continue
		return ImageTexture.create_from_image(image)
	return null


func _load_fallback(logical_name: String) -> Texture2D:
	var path := fallback_path(logical_name)
	if not ResourceLoader.exists(path):
		push_error("AssetResolver: missing template asset '%s'." % path)
		return null
	return load(path) as Texture2D
