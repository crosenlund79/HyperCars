extends GutTest
## Quick fix: the title screen's LAYOUT selector (Classic Circuit / Figure Eight
## (Experimental)), independent of the TRACK theme, applied to every kind of
## race, never saved, shown before racing; the classic circuit is unchanged.

const GAME_SCENE := preload("res://src/main/game.tscn")
const CLASSIC := "res://src/track/circuit_01.tres"
const FIGURE8 := "exp_figure8_01"

var _game: Node


func before_each() -> void:
	_game = GAME_SCENE.instantiate()
	_game.achievements_path = "user://test_layout_selection_ach.cfg"
	add_child_autofree(_game)
	await wait_frames(3)


func after_each() -> void:
	if is_instance_valid(_game):
		_game.title.stop_audio()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_layout_selection_ach.cfg"))


func _start(choice: int, with_garage := false, devices: Array[int] = []) -> Node2D:
	_game.start_race(choice, with_garage, devices)
	await wait_frames(30)
	return _game.race


func _back() -> void:
	_game.back_to_title()
	await wait_frames(30)


func test_selector_defaults_to_classic_and_cycles_without_saving() -> void:
	var t: TitleScreen = _game.title
	assert_eq(t.layout_id, DevLayouts.CLASSIC, "fresh launch: classic circuit")
	assert_eq(t._layout_button.text, "LAYOUT: CLASSIC CIRCUIT")
	t._cycle_layout()
	assert_eq(t.layout_id, FIGURE8)
	assert_eq(t._layout_button.text, "LAYOUT: FIGURE EIGHT (EXPERIMENTAL)")
	var cfg := ConfigFile.new()
	cfg.load(t.settings.path)
	assert_false(cfg.has_section_key("game", "layout"), "never saved")
	t._cycle_layout()
	assert_eq(t.layout_id, DevLayouts.CLASSIC, "back to classic")


func test_title_menu_fits_at_1280x720() -> void:
	var menu: Control = _game.title._main_menu
	await wait_frames(2)
	var r := Rect2(menu.global_position, menu.size)
	assert_true(Rect2(0, 0, 1280, 720).encloses(r), "menu %s on screen" % r)
	assert_lt(r.end.y, 686.0, "clear of the controls hint at the bottom")
	assert_true(_game.title._layout_button.is_visible_in_tree())


func test_classic_circuit_is_unchanged() -> void:
	var race := await _start(0)
	assert_eq(race.track.layout.resource_path, CLASSIC)
	assert_null(race.layout_override)
	assert_false(race.track.layout.has_elevation())
	assert_string_contains(race.hud_track_name, "Classic Circuit", "shown on the grid panel")


func test_layout_applies_to_every_kind_of_race_with_any_theme() -> void:
	_game.title.layout_id = FIGURE8
	var cases := [[0, false, [] as Array[int], "quick race"], [2, false, [] as Array[int], "spectating"],
		[0, true, [] as Array[int], "garage race"], [0, false, [3, 4] as Array[int], "couch two players"]]
	var variant := 1
	for c in cases:
		_game.title.track_variant = variant
		var race := await _start(c[0], c[1], c[2])
		assert_not_null(race, c[3])
		if race == null:
			continue
		assert_eq(DevLayouts.id_of(race.track.layout), FIGURE8, c[3])
		assert_eq(race.track.theme.variant, variant, c[3] + ": theme independent")
		assert_string_contains(race.hud_track_name, "Figure Eight (Experimental)", c[3] + ": shown before racing")
		variant = variant % 3 + 1
		await _back()


func test_menu_choice_wins_over_the_command_line_inside_the_game() -> void:
	# the developer argument only preselects the title button; the race uses the button
	_game.title.layout_id = DevLayouts.CLASSIC
	var race := await _start(0)
	assert_false(race.use_command_line_layout)
	assert_eq(race.track.layout.resource_path, CLASSIC)
	assert_eq(DevLayouts.load_layout(DevLayouts.CLASSIC), null)
	assert_eq(DevLayouts.ids()[0], DevLayouts.CLASSIC)
