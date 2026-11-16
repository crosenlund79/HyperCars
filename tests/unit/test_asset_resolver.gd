extends GutTest
## AssetResolver contract (assets/README.md): override precedence, missing and invalid
## fallback, supported format, override-root selection, caching, catalogue coverage.

var _root: String


func before_each() -> void:
	_root = OS.get_user_data_dir().path_join("test_overrides_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root.path_join("graphics/cars"))


func after_each() -> void:
	_remove_dir(_root)


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_dir(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)


func _write_png(rel: String, size: Vector2i) -> void:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	img.save_png(_root.path_join(rel))


func _write_bytes(rel: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(_root.path_join(rel), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func test_valid_png_override_takes_precedence() -> void:
	_write_png("graphics/cars/car_player.png", Vector2i(256, 144))
	var tex := AssetResolver.new(_root).get_texture(AssetCatalog.CAR_PLAYER)
	assert_eq(tex.get_size(), Vector2(256, 144))


func test_missing_override_uses_template() -> void:
	var tex := AssetResolver.new(_root).get_texture(AssetCatalog.CAR_PLAYER)
	assert_not_null(tex)
	assert_eq(tex.resource_path, "res://assets/graphics/cars/template_car_player.png")


func test_non_png_content_falls_back_with_warning() -> void:
	_write_bytes("graphics/cars/car_player.png", "not an image".to_utf8_buffer())
	var tex := AssetResolver.new(_root).get_texture(AssetCatalog.CAR_PLAYER)
	assert_eq(tex.resource_path, "res://assets/graphics/cars/template_car_player.png")
	assert_push_warning_count(1)


func test_corrupt_png_falls_back_with_warning() -> void:
	var bytes := PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4])
	_write_bytes("graphics/cars/car_player.png", bytes)
	var tex := AssetResolver.new(_root).get_texture(AssetCatalog.CAR_PLAYER)
	assert_eq(tex.resource_path, "res://assets/graphics/cars/template_car_player.png")
	assert_push_warning_count(1)
	# The engine's PNG decoder logs its own error for the corrupt buffer.
	for e in get_errors():
		e.handled = true


func test_unsupported_extension_is_not_used() -> void:
	_write_png("graphics/cars/car_player.jpg", Vector2i(8, 8))
	var tex := AssetResolver.new(_root).get_texture(AssetCatalog.CAR_PLAYER)
	assert_eq(tex.resource_path, "res://assets/graphics/cars/template_car_player.png")


func test_results_are_cached_for_the_session() -> void:
	var r := AssetResolver.new(_root)
	var first := r.get_texture(AssetCatalog.CAR_PLAYER)
	_write_png("graphics/cars/car_player.png", Vector2i(16, 16))
	assert_same(r.get_texture(AssetCatalog.CAR_PLAYER), first, "changes apply after restart only")


func test_override_root_selection() -> void:
	assert_eq(AssetResolver.compute_override_root(true, "/opt/godot/godot", "/proj/custom"), "/proj/custom")
	assert_eq(AssetResolver.compute_override_root(false, "/games/HyperCars/HyperCars.x86_64", "/proj/custom"),
		"/games/HyperCars/custom")
	assert_eq(AssetResolver.compute_override_root(false, "C:/Games/HyperCars/HyperCars.exe", "/proj/custom"),
		"C:/Games/HyperCars/custom")


func test_default_root_in_editor_is_project_custom_folder() -> void:
	if not OS.has_feature("editor"):
		pending("Only meaningful when running with the editor binary")
		return
	assert_eq(AssetResolver.new().override_root, ProjectSettings.globalize_path("res://custom"))


func test_fallback_path_mapping() -> void:
	assert_eq(AssetResolver.fallback_path("track/tarmac"), "res://assets/graphics/track/template_tarmac.png")
	assert_eq(AssetResolver.fallback_path("logo"), "res://assets/graphics/template_logo.png")


func test_every_catalogued_asset_has_a_template_of_declared_size() -> void:
	var r := AssetResolver.new(_root)
	for logical_name in AssetCatalog.SPECS:
		var tex := r.get_texture(logical_name)
		assert_not_null(tex, logical_name)
		if tex != null:
			assert_eq(Vector2i(tex.get_size()), AssetCatalog.SPECS[logical_name].template_size, logical_name)


func test_override_of_any_resolution_scales_to_display_size() -> void:
	var display: Vector2 = AssetCatalog.SPECS[AssetCatalog.CAR_PLAYER].display_size
	_write_png("graphics/cars/car_player.png", Vector2i(512, 288))
	var tex := AssetResolver.new(_root).get_texture(AssetCatalog.CAR_PLAYER)
	assert_eq(Vector2(tex.get_size()) * AssetCatalog.scale_for(tex, display), display)


# --- P2: car bodies, shared wheel and the flattened-car fallback ---

func test_template_cars_use_wheel_free_bodies_with_wheels() -> void:
	var r := AssetResolver.new(_root)
	var look := CarArt.look(r, "cars/car_ai_3")
	assert_true(look.wheels)
	assert_eq(look.body_logical, "cars/body_ai_3")
	assert_eq(look.body, r.get_texture("cars/body_ai_3"))
	assert_eq(CarArt.icon(r, "cars/car_ai_3"), r.get_texture("cars/car_ai_3"), "icons show the complete car")


func test_custom_flattened_car_is_drawn_alone_without_extra_wheels() -> void:
	_write_png("graphics/cars/car_player.png", Vector2i(256, 144))
	var r := AssetResolver.new(_root)
	assert_true(r.has_override("cars/car_player"))
	var look := CarArt.look(r, "cars/car_player")
	assert_false(look.wheels, "wheels are painted in: no duplicates")
	assert_eq(look.body.get_width(), 256, "the user's image")
	assert_eq(CarArt.icon(r, "cars/car_player").get_width(), 256)


func test_custom_body_gets_the_shared_wheels() -> void:
	_write_png("graphics/cars/car_player.png", Vector2i(256, 144))
	_write_png("graphics/cars/body_player.png", Vector2i(512, 288))
	var r := AssetResolver.new(_root)
	var look := CarArt.look(r, "cars/car_player")
	assert_true(look.wheels, "a body takes precedence over a flattened image")
	assert_eq(look.body.get_width(), 512)
	assert_eq(CarArt.icon(r, "cars/car_player").get_width(), 256, "icon: the complete flattened car")


func test_custom_body_only_is_also_the_icon() -> void:
	_write_png("graphics/cars/body_ai_1.png", Vector2i(128, 72))
	var r := AssetResolver.new(_root)
	assert_true(CarArt.look(r, "cars/car_ai_1").wheels)
	assert_eq(CarArt.icon(r, "cars/car_ai_1"), r.get_texture("cars/body_ai_1"))


func test_invalid_custom_body_falls_back_to_the_template_body() -> void:
	var f := FileAccess.open(_root.path_join("graphics/cars/body_ai_2.png"), FileAccess.WRITE)
	f.store_string("not a png")
	f.close()
	var r := AssetResolver.new(_root)
	assert_false(r.has_override("cars/body_ai_2"))
	var look := CarArt.look(r, "cars/car_ai_2")
	assert_true(look.wheels)
	assert_eq(look.body.get_width(), 128, "template body")


func test_shared_wheel_override_is_used() -> void:
	_write_png("graphics/cars/wheel.png", Vector2i(96, 56))
	var r := AssetResolver.new(_root)
	var wheel := r.get_texture(AssetCatalog.WHEEL)
	assert_eq(wheel.get_width(), 96)
	assert_eq(Vector2(wheel.get_size()) * AssetCatalog.scale_for(wheel, AssetCatalog.SPECS[AssetCatalog.WHEEL].display_size),
		AssetCatalog.SPECS[AssetCatalog.WHEEL].display_size, "any resolution, same display size")
