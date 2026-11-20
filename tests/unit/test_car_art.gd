extends GutTest
## One car artwork everywhere: the racing car (CarArt.look) and every static
## picture of it (CarArt.icon: title, standings, results, championship, garage,
## Nemesis Welcome, arena) come from the same artwork by the same rule:
##   body override (+ wheels) > legacy flattened override (as it is) > packaged body (+ wheels).
## Icons are the body with its four wheels composed in, so a car drawn once
## looks the same everywhere. Scratch override folder; never custom/.

var _root := ""


func before_each() -> void:
	_root = OS.get_user_data_dir().path_join("test_run/car_art_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root.path_join("graphics/cars"))
	CarArt.clear_cache()


func after_each() -> void:
	for f in DirAccess.get_files_at(_root.path_join("graphics/cars")):
		DirAccess.remove_absolute(_root.path_join("graphics/cars").path_join(f))
	CarArt.clear_cache()


## A test body: a GREEN car body (opaque rows 12..59 of 72, like the templates
## leave room for the wheels above and below), 128 x 72.
func _body(name: String, colour := Color(0.1, 0.8, 0.2)) -> void:
	var img := Image.create(128, 72, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(8, 16, 112, 40), colour)
	img.save_png(_root.path_join("graphics/cars/%s.png" % name))


func _pixel(tex: Texture2D, at: Vector2i) -> Color:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	return img.get_pixelv(at)


func test_default_icon_is_the_racing_body_with_its_wheels() -> void:
	var r := AssetResolver.new(_root)
	var l := CarArt.look(r, AssetCatalog.CAR_PLAYER)
	assert_true(l.wheels)
	assert_eq(l.body.resource_path, "res://assets/graphics/cars/template_body_player.png", "races draw the packaged body")
	var icon := CarArt.icon(r, AssetCatalog.CAR_PLAYER)
	assert_ne(icon.resource_path, "res://assets/graphics/cars/template_car_player.png", "never the legacy flattened picture")
	assert_eq(_pixel(icon, Vector2i(64, 36)), _pixel(l.body, Vector2i(64, 36)), "the same body in the middle")
	# a wheel under the body: front-right wheel centre (display +16.5, +12 -> image 97, 60)
	assert_gt(_pixel(icon, Vector2i(97, 64)).a, _pixel(l.body, Vector2i(97, 64)).a + 0.3,
		"the wheel peeks out below the body, as on the racing car")
	assert_eq(CarArt.icon(r, AssetCatalog.CAR_PLAYER), icon, "composed once, then reused")


func test_a_body_override_shows_everywhere_with_wheels() -> void:
	_body("body_player")
	var r := AssetResolver.new(_root)
	var l := CarArt.look(r, AssetCatalog.CAR_PLAYER)
	assert_true(l.wheels, "the race adds the four animated wheels")
	assert_almost_eq(_pixel(l.body, Vector2i(64, 36)).g, 0.8, 0.02, "the user's body in the race")
	var icon := CarArt.icon(r, AssetCatalog.CAR_PLAYER)
	assert_almost_eq(_pixel(icon, Vector2i(64, 36)).g, 0.8, 0.02, "the same green body in every picture")
	assert_gt(_pixel(icon, Vector2i(97, 62)).a, 0.5, "with its wheels")
	assert_gt(_pixel(icon, Vector2i(31, 10)).a, 0.5, "all four (rear-left)")


func test_a_legacy_flattened_override_alone_is_used_everywhere_without_extra_wheels() -> void:
	_body("car_player", Color(0.9, 0.1, 0.1))
	var r := AssetResolver.new(_root)
	var l := CarArt.look(r, AssetCatalog.CAR_PLAYER)
	assert_false(l.wheels, "painted-in wheels: no extra wheels in the race")
	assert_almost_eq(_pixel(l.body, Vector2i(64, 36)).r, 0.9, 0.02, "the race uses it (not silently ignored)")
	var icon := CarArt.icon(r, AssetCatalog.CAR_PLAYER)
	assert_eq(icon, l.body, "the pictures show exactly the same image")
	assert_eq(_pixel(icon, Vector2i(97, 62)).a, 0.0, "nothing added")


func test_with_both_the_body_wins_everywhere() -> void:
	_body("car_player", Color(0.9, 0.1, 0.1))  # an older flattened drawing
	_body("body_player")  # the new body (green)
	var r := AssetResolver.new(_root)
	var l := CarArt.look(r, AssetCatalog.CAR_PLAYER)
	assert_true(l.wheels)
	assert_almost_eq(_pixel(l.body, Vector2i(64, 36)).g, 0.8, 0.02, "the race: the body")
	assert_almost_eq(_pixel(CarArt.icon(r, AssetCatalog.CAR_PLAYER), Vector2i(64, 36)).g, 0.8, 0.02,
		"the pictures: the same body (the menu / race mismatch is gone)")


func test_rivals_junker_and_player_two_follow_the_same_rule() -> void:
	_body("body_ai_4", Color(0.2, 0.3, 0.9))
	var r := AssetResolver.new(_root)
	for car in [AssetCatalog.ai_car(4), AssetCatalog.CAR_JUNKER, AssetCatalog.CAR_PLAYER_2]:
		var l := CarArt.look(r, car)
		var icon := CarArt.icon(r, car)
		assert_true(l.wheels, car)
		assert_eq(_pixel(icon, Vector2i(64, 36)), _pixel(l.body, Vector2i(64, 36)), "%s: icon = racing body" % car)
	assert_almost_eq(_pixel(CarArt.icon(r, AssetCatalog.ai_car(4)), Vector2i(64, 36)).b, 0.9, 0.02, "Hank's custom body")
	assert_true(CarArt.look(r, AssetCatalog.ai_car(5)).body.resource_path.ends_with("template_body_ai_5.png"), "others unchanged")


func test_higher_resolution_bodies_get_proportionate_wheels() -> void:
	var img := Image.create(256, 144, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(16, 32, 224, 80), Color(0.1, 0.8, 0.2))
	img.save_png(_root.path_join("graphics/cars/body_player.png"))
	var r := AssetResolver.new(_root)
	var icon := CarArt.icon(r, AssetCatalog.CAR_PLAYER)
	assert_eq(icon.get_size(), Vector2(256, 144), "composed at the drawing's own resolution")
	assert_gt(_pixel(icon, Vector2i(194, 124)).a, 0.5, "the wheel scaled with it")


func test_the_packaged_legacy_pictures_match_the_bodies_and_wheel() -> void:
	# The legacy flattened templates are generated from the bodies and the wheel
	# (docs/ARTWORK_MASTER_LIST.md): no second, different master of any car.
	var r := AssetResolver.new(_root)
	for name in ["player", "player_2", "junker"] + range(1, 10).map(func(i: int) -> String: return "ai_%d" % i):
		var composed := CarArt.icon(r, "cars/car_" + name).get_image()
		var legacy := (load("res://assets/graphics/cars/template_car_%s.png" % name) as Texture2D).get_image()
		if legacy.is_compressed():
			legacy.decompress()
		legacy.convert(Image.FORMAT_RGBA8)
		var diff := 0.0
		for y in range(0, 72, 3):
			for x in range(0, 128, 3):
				var a := composed.get_pixel(x, y)
				var b := legacy.get_pixel(x, y)
				# (as seen: colours weighted by opacity; the importer recolours fully transparent pixels)
				diff += absf(a.r * a.a - b.r * b.a) + absf(a.g * a.a - b.g * b.a) + absf(a.b * a.a - b.b * b.a) + absf(a.a - b.a)
		assert_lt(diff / (43.0 * 24.0), 0.01, "%s: legacy picture = body + wheels" % name)
