extends GutTest
## P1 Stage 1: HUD and layout corrections (presentation only). The FINISH!
## banner fades before the results appear; GO! sits clear of the grid; the
## standings tower has a backing and highlights the human(s) in their identity
## colours; split-screen views keep their DESTROYED countdown and a compact
## tower inside their own half; garage disabled buttons read as inactive.

const MAIN_SCENE := preload("res://src/main/main.tscn")
const P1 := RaceSession.PLAYER_ID
const P2 := RaceSession.PLAYER_2_ID

var _main: Node2D


func after_each() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8


func _make(humans := 1) -> void:
	_main = MAIN_SCENE.instantiate()
	_main.presentation_enabled = false
	if humans == 2:
		_main.human_count = 2
		_main.player_devices = [3, 4] as Array[int]
	add_child_autofree(_main)
	await wait_physics_frames(2)


func _finish(id: int) -> void:
	var cps: int = _main.track.checkpoint_count()
	for lap in _main.session.lap_count():
		for i in range(1, cps):
			_main.session.checkpoint_reached(i, id)
		_main.session.checkpoint_reached(0, id)


## Screen rectangle of a HUD control (the HUD's canvas layer may be offset).
func _screen_rect(hud: Hud, c: Control) -> Rect2:
	return Rect2(hud.offset + c.position, c.size)


func test_results_wait_for_the_finish_banner_to_fade() -> void:
	await _make()
	var hud: Hud = _main.hud
	_main.start_race()
	hud.flash_banner("FINISH!")
	hud.show_results(_main.session.standings())
	assert_true(hud.banner_showing())
	assert_true(hud._message.visible, "results prepared")
	assert_eq(hud._message.modulate.a, 0.0, "not shown on top of the banner")
	await wait_seconds(1.0)
	assert_eq(hud._message.modulate.a, 0.0, "still waiting while the banner is up")
	await wait_seconds(0.8)
	assert_false(hud.banner_showing())
	assert_eq(hud._banner.modulate.a, 0.0, "banner gone")
	assert_gt(hud._message.modulate.a, 0.9, "results faded in afterwards")


func test_results_without_a_banner_appear_at_once() -> void:
	await _make()
	var hud: Hud = _main.hud
	hud.show_results(_main.session.standings())
	await wait_seconds(0.4)
	assert_gt(hud._message.modulate.a, 0.9)


func test_go_banner_is_short_and_clear_of_the_starting_grid() -> void:
	await _make()
	var hud: Hud = _main.hud
	var r := _screen_rect(hud, hud._banner)
	assert_lt(r.end.y, 230.0, "upper part of the screen; the grid sits around the centre")
	assert_lt(_main.GO_BANNER_HOLD, Hud.BANNER_HOLD, "GO! leaves sooner than FINISH!")
	_main.start_race()
	await wait_seconds(1.1)
	assert_false(hud.banner_showing(), "GO! gone within about a second")


func test_tower_has_a_backing_and_highlights_the_player() -> void:
	await _make()
	var hud: Hud = _main.hud
	_main.start_race()
	await wait_physics_frames(2)
	assert_true(hud._tower_panel.visible, "translucent backing")
	assert_lt(hud._tower_panel.self_modulate.a, 1.0)
	var you: Array = hud._tower_rows.filter(func(p: Array) -> bool: return p[3].text == "YOU")
	assert_eq(you.size(), 1)
	assert_true(you[0][0].get_theme_stylebox("panel") is StyleBoxFlat, "player row boxed")
	var other: Array = hud._tower_rows.filter(func(p: Array) -> bool: return p[3].text != "YOU")
	assert_true(other[0][0].get_theme_stylebox("panel") is StyleBoxEmpty, "rivals plain")


func test_results_box_the_player_row() -> void:
	await _make()
	var hud: Hud = _main.hud
	_main.start_race()
	_finish(P1)
	hud.show_results(_main.session.standings())
	var boxed: Array = hud._message_box.find_children("*", "PanelContainer", true, false).filter(
		func(p: PanelContainer) -> bool: return p.get_theme_stylebox("panel") is StyleBoxFlat)
	assert_eq(boxed.size(), 1, "exactly the player's row")
	var names: Array = boxed[0].find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(names, "YOU")


func test_split_screen_views_keep_their_own_countdown_and_tower() -> void:
	await _make(2)
	_main.set_weapons_enabled(true)
	_main.start_race()
	await wait_physics_frames(2)
	var views: Array = _main.player_views.views
	assert_false(_main.hud._tower_box.visible, "no shared tower over the divider")
	var halves: Array[Rect2] = []
	for v in views:
		halves.append(Rect2(v.container.position, v.base_size))
	var labels: Array[Rect2] = []
	for v in views:
		_main.combat.wreck_left[v.racer_id] = 2.0  # both players destroyed
	await wait_physics_frames(1)
	await wait_process_frames(1)
	for k in views.size():
		var h: Hud = views[k].hud
		assert_true(h._wreck_label.visible)
		var box := _screen_rect(h, h._wreck_label)
		assert_true(halves[k].encloses(box), "DESTROYED label inside its own view")
		# the centred text itself
		var w := h._wreck_label.get_minimum_size().x
		var lr := Rect2(box.position.x + (box.size.x - w) * 0.5, box.position.y, w, box.size.y)
		labels.append(lr)
		assert_true(h._tower_box.visible, "compact tower in the view")
		var tr := _screen_rect(h, h._tower_box)
		tr.size = h._tower_box.get_combined_minimum_size()
		assert_true(halves[k].encloses(tr), "tower inside its own view")
		assert_false(tr.intersects(lr), "tower clear of the countdown")
	assert_false(labels[0].intersects(labels[1]), "no overlap at the divider")
	assert_lt(_screen_rect(views[0].hud, views[0].hud._tower_box).position.x, 100.0, "P1: left edge")
	assert_gt(_screen_rect(views[1].hud, views[1].hud._tower_box).position.x, 1000.0, "P2: right edge")


func test_split_screen_rows_use_player_colours() -> void:
	await _make(2)
	_main.start_race()
	await wait_physics_frames(2)
	var views: Array = _main.player_views.views
	for k in views.size():
		var h: Hud = views[k].hud
		var own := "P1" if k == 0 else "P2"
		for parts in h._tower_rows:
			var name: String = parts[3].text
			if name == "P1" or name == "P2":
				var col: Color = parts[3].get_theme_color("font_color")
				assert_eq(col, HyperTheme.player_color(0 if name == "P1" else 1), name + " colour")
				assert_eq(parts[0].get_theme_stylebox("panel") is StyleBoxFlat, name == own, "only own row boxed")
		assert_eq(h._mode_label.get_theme_color("font_color"), HyperTheme.player_color(k))
	assert_ne(HyperTheme.player_color(0), HyperTheme.player_color(1))
	_finish(P1)
	_finish(P2)
	await wait_physics_frames(3)
	var boxed: Array = _main.hud._message_box.find_children("*", "PanelContainer", true, false).filter(
		func(p: PanelContainer) -> bool: return p.get_theme_stylebox("panel") is StyleBoxFlat)
	assert_eq(boxed.size(), 2, "both humans boxed on the shared results")


func test_garage_disabled_buttons_read_as_inactive() -> void:
	var garage := PlayerGarage.new(load("res://src/garage/default_garage_rules.tres"))
	var screen := GarageScreen.new()
	add_child_autofree(screen)
	screen.setup(garage, AssetResolver.new())
	screen.open()
	var card: Dictionary = screen._cards[WeaponRules.Weapon.SUPER_MISSILE]
	garage.money = 0
	screen.refresh()
	assert_true(card.buy.disabled)
	assert_eq(card.buy.get_theme_color("font_disabled_color"), GarageScreen.DISABLED_TEXT)
	assert_eq((card.buy.get_theme_stylebox("disabled") as StyleBoxTexture).modulate_color, GarageScreen.DISABLED_PLATE)
	var mounted: Dictionary = screen._cards[garage.equipped[PlayerGarage.FRONT]]
	assert_true(mounted.equip.disabled)
	assert_eq(mounted.equip.get_theme_color("font_disabled_color"), HyperTheme.GOLD, "EQUIPPED is a state, in gold")


# --- P1 Stage 2: combat readability (presentation only) ---

func _make_presented(humans := 1) -> void:
	_main = MAIN_SCENE.instantiate()
	_main.presentation_enabled = true
	if humans == 2:
		_main.human_count = 2
		_main.player_devices = [3, 4] as Array[int]
	add_child_autofree(_main)
	await wait_physics_frames(2)


## Combat state is injected on the grid (before the start nothing moves it), so
## only the presentation is exercised.
func test_missiles_leave_a_short_trail_that_stops_with_them() -> void:
	await _make_presented()
	_main.set_weapons_enabled(true)
	var view: CombatView = _main.combat_view
	_main.combat.projectiles.append({"type": WeaponRules.Weapon.FRONT_MISSILE, "owner": P1,
		"pos": Vector2(300, 200), "dir": Vector2.RIGHT, "age": 0.1})
	await wait_process_frames(2)
	assert_eq(view._trails.size(), view._missiles.size(), "one trail per missile sprite")
	assert_true(view._trails[0].emitting, "trail while the missile flies")
	assert_almost_eq(view._trails[0].global_position.distance_to(Vector2(300, 200)), 0.0, 0.01)
	assert_lt(view._trails[0].lifetime, 0.5, "short-lived")
	_main.combat.projectiles.clear()
	await wait_process_frames(1)
	assert_false(view._trails[0].emitting, "stops with its missile")


func test_mines_get_a_halo_under_the_sprite() -> void:
	await _make_presented()
	_main.set_weapons_enabled(true)
	var view: CombatView = _main.combat_view
	_main.combat.mines.append({"owner": P1, "pos": Vector2(300, 200), "age": 0.5})
	await wait_process_frames(2)
	assert_eq(view._mines.size(), 1)
	assert_true(view._mines[0].visible)
	assert_lt(view._halos.z_index, 0, "halo under the cars")
	assert_true(view._halos.get_index() < view._mines[0].get_index(), "drawn before (under) the mine sprite")


func test_marker_on_the_local_car_only() -> void:
	await _make_presented()
	assert_eq(_main.player_marker.marked, {P1: HyperTheme.GOLD})


func test_split_screen_marks_both_players_in_their_colours() -> void:
	await _make_presented(2)
	assert_eq(_main.player_marker.marked, {P1: HyperTheme.player_color(0), P2: HyperTheme.player_color(1)})


func test_network_race_marks_only_this_computers_car_in_gold() -> void:
	var host_link := NetLink.new()
	var client_link := NetLink.new()
	add_child_autofree(host_link)
	add_child_autofree(client_link)
	host_link.host(24733)
	client_link.join("127.0.0.1", 24733)
	await wait_until(func() -> bool: return host_link.peers().size() == 1 and client_link.peers().size() == 1, 5.0)
	var mains: Array[Node2D] = []
	for role in [NetRace.Role.HOST, NetRace.Role.CLIENT]:
		var m: Node2D = MAIN_SCENE.instantiate()
		m.presentation_enabled = true
		m.human_count = 2
		m.net = NetRace.new(host_link if role == NetRace.Role.HOST else client_link, role)
		var parent: Node = self
		if role == NetRace.Role.CLIENT:
			parent = SubViewport.new()
			add_child_autofree(parent)
		parent.add_child(m)
		if parent == self:
			autofree(m)
		mains.append(m)
	await wait_physics_frames(5)
	assert_eq(mains[0].player_marker.marked, {P1: HyperTheme.GOLD}, "host marks its own car")
	assert_eq(mains[1].player_marker.marked, {P2: HyperTheme.GOLD}, "client marks its own car")
	assert_eq(mains[0].hud._human_colors[P2], HyperTheme.P2_BLUE, "the other human in blue")
	assert_eq(mains[1].hud._human_colors[P1], HyperTheme.P2_BLUE)
	assert_eq(mains[1].hud._own_ids, [P2] as Array[int])
	host_link.close()
	client_link.close()


func test_spectator_banner_stays_clear_of_the_history_panel() -> void:
	await _make()
	var hud: Hud = _main.hud
	_main.set_menu_choice(2)  # spectate (chosen on the grid panel)
	assert_true(hud.history_panel.visible)
	var banner := _screen_rect(hud, hud._banner)
	var history := Rect2(hud.history_panel.position, hud.history_panel.size)
	assert_false(banner.intersects(history), "winner banner below the history panel")
	_main.set_menu_choice(0)
	assert_eq(hud._banner.position.y, Hud.BANNER_Y, "back at the top when racing")


# --- P2 Stage 1: engine voices (presentation only) ---

func test_engines_limit_rival_voices_and_always_play_your_own() -> void:
	await _make_presented()
	_main.inputs[P1] = AiDriverInput.new(P1, AiDriver.new(_main.racing_line, load(RivalRoster.params_path(2))))
	_main.start_race()
	await wait_physics_frames(240)
	var audio: RaceAudio = _main.race_audio
	assert_eq(audio.local_ids, [P1] as Array[int])
	assert_true(audio._engines[P1].playing, "own engine")
	assert_true(audio._loads[P1].playing, "own load layer")
	await wait_seconds(audio.engine_params.voice_fade + 0.1)
	var rivals := 0
	for i in _main.cars.size():
		if i != P1 and audio._engines[i].playing:
			rivals += 1
	assert_lte(rivals, audio.engine_params.max_rival_voices, "only the nearest rivals are heard")
	assert_lt(audio._engines[P1].pitch_scale, 1.5, "deep pitch range")
