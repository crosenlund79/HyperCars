class_name TitleScreen
extends Node
## Title screen: the circuit with its scenery and the ten cars parked on the
## grid as a slowly panning painted backdrop, the logo, and the menus
## (Race / Spectate / Settings / Controls / Quit). Presentation only.

## choice: 0 Fire to Accelerate, 1 Fire to Brake, 2 Spectate; garage: garage race.
signal start_requested(choice: int, garage: bool)
## Two-player split-screen with the joined devices (Player 1 first).
signal two_player_requested(devices: Array[int])
## LAN race (M5.1): the game root hosts / joins / cancels and reports status.
signal lan_host_requested
signal lan_join_requested(address: String)
signal lan_cancel_requested
## Weapons ON / No Guns preference for both racing and spectating (saved).
var weapons_on := true
var _weapons_button: Button
## Race length preference (laps) for racing and spectating (saved).
var laps := 3
var _laps_button: Button
## Track theme variant for racing and spectating (saved); the backdrop shows it.
var track_variant := 1
var _track_button: Button
## Track layout id (DevLayouts; "" = Classic Circuit). Not saved: a launch starts
## on the classic circuit unless the developer "--layout=<id>" argument is given.
var layout_id: String = DevLayouts.selected_id()
var _layout_button: Button
## Combat style preference (WeaponRules.Style) for racing and spectating (saved).
var combat_style := 0
var _style_button: Button
signal quit_requested

const TRACK_SCRIPT := preload("res://src/track/track.gd")
const LAYOUT := preload("res://src/track/circuit_01.tres")

var resolver: AssetResolver
var settings: AudioSettings
var _backdrop: Node2D
var _camera: Camera2D
var _path: ClosedPath
var _pan := 0.0
var _ui: CanvasLayer
var _logo: TextureRect
var _tagline: Label
var _main_menu: VBoxContainer
var _race_menu: VBoxContainer
var _settings_panel: SettingsPanel
var _controls_panel: ControlsPanel
var _achievements_panel: AchievementsPanel
var _join_panel: JoinPanel
var lan_panel: LanPanel
## Achievement store shown by the ACHIEVEMENTS panel (set before setup; may be null).
var achievements: AchievementStore
var _music: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _time := 0.0


func setup(p_resolver: AssetResolver, p_settings: AudioSettings) -> void:
	resolver = p_resolver
	settings = p_settings
	var pref := ConfigFile.new()
	if pref.load(settings.path) == OK:
		track_variant = clampi(int(pref.get_value("game", "track_variant", 1)), 1, TrackTheme.VARIANT_COUNT)
	_build_backdrop()
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var root := Control.new()
	root.theme = HyperTheme.build(resolver)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.08, 0.07, 0.35)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	_logo = TextureRect.new()
	_logo.texture = resolver.get_texture(AssetCatalog.LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.size = AssetCatalog.SPECS[AssetCatalog.LOGO].display_size
	_logo.position = Vector2((1280 - _logo.size.x) * 0.5, 40)
	_logo.pivot_offset = _logo.size * 0.5
	root.add_child(_logo)
	_tagline = HyperTheme.label("Top-down combat racing, hand-painted", 20, HyperTheme.CREAM, 500)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.size = Vector2(1280, 30)
	_tagline.position = Vector2(0, 214)
	root.add_child(_tagline)

	_load_weapons_pref()
	_main_menu = _menu(root, [["RACE", _open_race], ["SPECTATE RIVALS", func() -> void: _start(2)],
		["WEAPONS", _toggle_weapons], ["COMBAT", _toggle_style], ["LAPS", _cycle_laps], ["TRACK", _cycle_track],
		["LAYOUT", _cycle_layout], ["ACHIEVEMENTS", _open_achievements],
		["SETTINGS", _open_settings], ["CONTROLS", _open_controls], ["QUIT", func() -> void: quit_requested.emit()]],
		380, 34, 3)  # eleven entries: a little tighter, clear of the footer at 1280x720
	_weapons_button = _main_menu.get_child(2)
	_style_button = _main_menu.get_child(3)
	_laps_button = _main_menu.get_child(4)
	_track_button = _main_menu.get_child(5)
	_layout_button = _main_menu.get_child(6)
	_update_track_button()
	_update_layout_button()
	_update_weapons_button()
	_update_style_button()
	_update_laps_button()
	_race_menu = _menu(root, [["QUICK RACE: FIRE TO ACCELERATE", func() -> void: _start(0)],
		["QUICK RACE: FIRE TO BRAKE", func() -> void: _start(1)],
		["GARAGE RACE: FIRE TO ACCELERATE", func() -> void: _start(0, true)],
		["GARAGE RACE: FIRE TO BRAKE", func() -> void: _start(1, true)],
		["TWO PLAYERS: SPLIT SCREEN", _open_join],
		["TWO PLAYERS: LAN / ONLINE", _open_lan],
		["BACK", _show_main]], 520)
	var race_title := HyperTheme.label("QUICK RACE: standard weapons\nGARAGE RACE: prize money and your own weapons", 18, HyperTheme.GOLD, 600)
	race_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_menu.add_child(race_title)
	_race_menu.move_child(race_title, 0)

	_settings_panel = SettingsPanel.new()
	root.add_child(_settings_panel)
	_settings_panel.setup(settings)
	_settings_panel.closed.connect(_show_main)
	_controls_panel = ControlsPanel.new()
	root.add_child(_controls_panel)
	_controls_panel.setup()
	_controls_panel.closed.connect(_show_main)
	_join_panel = JoinPanel.new()
	root.add_child(_join_panel)
	_join_panel.setup()
	_join_panel.closed.connect(_open_race)
	_join_panel.confirmed.connect(func(devices: Array[int]) -> void:
		_sfx_play("ui/ui_select")
		two_player_requested.emit(devices))
	_join_panel.reset_size()
	_join_panel.position = Vector2((1280 - _join_panel.size.x) * 0.5, 300)
	lan_panel = LanPanel.new()
	root.add_child(lan_panel)
	var saved := ConfigFile.new()
	saved.load(settings.path)
	lan_panel.setup(str(saved.get_value("game", "lan_address", "")))
	lan_panel.host_requested.connect(func() -> void:
		_sfx_play("ui/ui_select")
		lan_host_requested.emit())
	lan_panel.join_requested.connect(func(address: String) -> void:
		_sfx_play("ui/ui_select")
		var cfg := ConfigFile.new()
		cfg.load(settings.path)
		cfg.set_value("game", "lan_address", address)
		cfg.save(settings.path)
		lan_join_requested.emit(address))
	lan_panel.cancel_requested.connect(func() -> void: lan_cancel_requested.emit())
	lan_panel.closed.connect(_open_race)
	lan_panel.reset_size()
	lan_panel.position = Vector2((1280 - lan_panel.size.x) * 0.5, 290)
	_achievements_panel = AchievementsPanel.new()
	root.add_child(_achievements_panel)
	_achievements_panel.setup(achievements if achievements != null else AchievementStore.new("user://unused_achievements.cfg"), resolver)
	_achievements_panel.closed.connect(_show_main)
	_achievements_panel.refresh()
	_achievements_panel.reset_size()
	_achievements_panel.position = (Vector2(1280, 720) - _achievements_panel.size) * 0.5
	for panel in [_settings_panel, _controls_panel]:
		panel.reset_size()
		panel.position = Vector2((1280 - panel.size.x) * 0.5, 250 if panel == _settings_panel else (720 - panel.size.y) * 0.5 - 10)
	var footer := HyperTheme.label("Esc: back    Enter / Space: select", 15, HyperTheme.CREAM_DIM, 500)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.size = Vector2(1280, 24)
	footer.position = Vector2(0, 686)
	root.add_child(footer)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = resolver.get_audio("music/music_menu", true)
	add_child(_music)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Effects"
	add_child(_sfx)
	show_title()


## Shows the title (backdrop, menus, music) and focuses the first button.
func show_title() -> void:
	_backdrop.visible = true
	_camera.enabled = true
	_camera.make_current()
	_ui.visible = true
	set_process(true)
	if not _music.playing:
		_music.play()
	_show_main()


## Hides everything while a race runs (keeps the scene for a quick return).
func hide_title() -> void:
	_ui.visible = false
	_backdrop.visible = false
	_camera.enabled = false
	set_process(false)
	_music.stop()


func stop_audio() -> void:
	_music.stop()
	_music.stream = null
	_sfx.stop()
	_sfx.stream = null


func _process(delta: float) -> void:
	_time += delta
	_pan = fposmod(_pan + delta * 70.0, _path.length)
	_camera.global_position = _path.point_at(_pan) + Vector2(0, 120)
	_logo.scale = Vector2.ONE * (1.0 + sin(_time * 1.6) * 0.012)
	_logo.rotation = sin(_time * 0.9) * 0.008


func _unhandled_input(event: InputEvent) -> void:
	if not _ui.visible:
		return
	if event.is_action_pressed("ui_cancel") and not _main_menu.visible:
		_sfx_play("ui/ui_back")
		_show_main()
		get_viewport().set_input_as_handled()


func _toggle_weapons() -> void:
	_sfx_play("ui/ui_select")
	weapons_on = not weapons_on
	_update_weapons_button()
	var cfg := ConfigFile.new()
	cfg.load(settings.path)
	cfg.set_value("game", "weapons", weapons_on)
	cfg.save(settings.path)


func _cycle_laps() -> void:
	_sfx_play("ui/ui_select")
	var options: Array[int] = [3, 7, 20, 50]
	laps = options[(options.find(laps) + 1) % options.size()]
	_update_laps_button()
	var cfg := ConfigFile.new()
	cfg.load(settings.path)
	cfg.set_value("game", "laps", laps)
	cfg.save(settings.path)


func _toggle_style() -> void:
	_sfx_play("ui/ui_select")
	combat_style = WeaponRules.Style.TACTICAL if combat_style == WeaponRules.Style.CLASSIC else WeaponRules.Style.CLASSIC
	_update_style_button()
	var cfg := ConfigFile.new()
	cfg.load(settings.path)
	cfg.set_value("game", "combat_style", combat_style)
	cfg.save(settings.path)


func _update_style_button() -> void:
	_style_button.text = "COMBAT: %s" % WeaponRules.style_name(combat_style)


func _cycle_track() -> void:
	_sfx_play("ui/ui_select")
	track_variant = track_variant % TrackTheme.VARIANT_COUNT + 1
	_update_track_button()
	var cfg := ConfigFile.new()
	cfg.load(settings.path)
	cfg.set_value("game", "track_variant", track_variant)
	cfg.save(settings.path)
	var pan := _pan
	_backdrop.free()
	_build_backdrop()
	_pan = pan
	_camera.make_current()


## Classic Circuit -> Figure Eight (Experimental) -> ... (not saved).
func _cycle_layout() -> void:
	_sfx_play("ui/ui_select")
	var ids := DevLayouts.ids()
	layout_id = ids[(ids.find(layout_id) + 1) % ids.size()]
	_update_layout_button()
	var pan := _pan
	_backdrop.free()
	_build_backdrop()
	_pan = pan
	_camera.make_current()


func _update_layout_button() -> void:
	_layout_button.text = "LAYOUT: %s" % DevLayouts.display_name(layout_id).to_upper()


func _update_track_button() -> void:
	_track_button.text = "TRACK: %s" % TrackTheme.load_variant(track_variant).display_name.to_upper()


func _update_laps_button() -> void:
	_laps_button.text = "LAPS: %d" % laps


func _update_weapons_button() -> void:
	_weapons_button.text = "WEAPONS: ON" if weapons_on else "WEAPONS: NO GUNS"


func _load_weapons_pref() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings.path) == OK:
		weapons_on = bool(cfg.get_value("game", "weapons", true))
		var saved := int(cfg.get_value("game", "laps", 3))
		laps = saved if [3, 7, 20, 50].has(saved) else 3
		combat_style = clampi(int(cfg.get_value("game", "combat_style", 0)), 0, 1)


func _start(choice: int, garage: bool = false) -> void:
	_sfx_play("ui/ui_select")
	start_requested.emit(choice, garage)


func _open_race() -> void:
	_sfx_play("ui/ui_select")
	_show_only(_race_menu)
	(_race_menu.get_child(1) as Button).grab_focus()


func _open_settings() -> void:
	_sfx_play("ui/ui_select")
	_show_only(_settings_panel)
	_settings_panel.focus_first()


func _open_lan() -> void:
	_sfx_play("ui/ui_select")
	_show_only(lan_panel)
	lan_panel.open()


func _open_join() -> void:
	_sfx_play("ui/ui_select")
	_join_panel.open()
	_show_only(_join_panel)
	_join_panel.reset_size()


func _open_achievements() -> void:
	_sfx_play("ui/ui_select")
	_achievements_panel.refresh()
	_show_only(_achievements_panel)
	_achievements_panel.focus_first()


func _open_controls() -> void:
	_sfx_play("ui/ui_select")
	_show_only(_controls_panel)
	_controls_panel.focus_first()


func _show_main() -> void:
	_show_only(_main_menu)
	(_main_menu.get_child(0) as Button).grab_focus()


func _show_only(node: Control) -> void:
	for n in [_main_menu, _race_menu, _settings_panel, _controls_panel, _achievements_panel, _join_panel, lan_panel]:
		n.visible = n == node
	_logo.visible = node != _controls_panel and node != _achievements_panel
	_tagline.visible = _logo.visible
	node.modulate.a = 0.0
	create_tween().tween_property(node, "modulate:a", 1.0, 0.18)


func _menu(root: Control, items: Array, width: int = 380, button_height: int = 38, gap: int = 4) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	box.custom_minimum_size = Vector2(width, 0)
	root.add_child(box)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(width, button_height)
		b.add_theme_font_size_override("font_size", 20)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb: StyleBox = root.theme.get_stylebox(state, "Button").duplicate()
			sb.content_margin_top = 4
			sb.content_margin_bottom = 6
			b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(item[1])
		b.focus_entered.connect(func() -> void: _sfx_play("ui/ui_move"))
		b.mouse_entered.connect(b.grab_focus)
		box.add_child(b)
	box.reset_size()
	box.position = Vector2((1280 - width) * 0.5, 244)
	return box


func _sfx_play(logical: String) -> void:
	if _sfx == null:
		return
	_sfx.stream = resolver.get_audio(logical)
	_sfx.play()


func _build_backdrop() -> void:
	_backdrop = Node2D.new()
	add_child(_backdrop)
	var track := Node2D.new()
	track.set_script(TRACK_SCRIPT)
	var chosen := DevLayouts.load_layout(layout_id)
	track.layout = chosen if chosen != null else LAYOUT
	_backdrop.add_child(track)
	track.build(resolver, TrackTheme.load_variant(track_variant))
	# The backdrop never races: remove its collision and checkpoint nodes.
	for child in track.get_children():
		if child is CollisionObject2D:
			child.queue_free()
	var decals := Node2D.new()
	_backdrop.add_child(decals)
	var scenery := TrackScenery.new()
	_backdrop.add_child(scenery)
	scenery.build(track, resolver, decals)
	var names := ["cars/car_player"]
	for i in range(1, 10):
		names.append(AssetCatalog.ai_car(i))
	for slot in names.size():
		var spr := Sprite2D.new()
		spr.texture = CarArt.icon(resolver, names[(slot + 1) % names.size()])
		var t: Transform2D = track.grid_transform(slot)
		spr.position = t.origin
		spr.rotation = t.get_rotation()
		spr.scale = AssetCatalog.scale_for(spr.texture, AssetCatalog.SPECS[AssetCatalog.CAR_PLAYER].display_size)
		_backdrop.add_child(spr)
	_path = track.path
	_pan = _path.length - 700.0
	_camera = Camera2D.new()
	_camera.zoom = Vector2(0.9, 0.9)
	_backdrop.add_child(_camera)
