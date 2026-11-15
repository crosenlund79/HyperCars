class_name Hud
extends CanvasLayer
## Race HUD: info panel (position, lap, time, mode), live position tower,
## centre panels for the mode menu and results, GO!/FINISH! banners and the
## spectator history. Presentation only: it displays race state it is given.

const PLAYER_ID := 0
## GO! / FINISH! banner: top of the screen, clear of the starting grid and the
## cars around the camera centre; low between the views in split-screen.
const BANNER_Y := 56.0
const BANNER_Y_SPLIT := 530.0
const BANNER_HOLD := 0.6
## Spectator camera: a standings row was clicked (racer id), or an arrow was
## pressed (-1 previous / +1 next in the starting-grid order).
signal follow_requested(id: int)
signal follow_step_requested(direction: int)

var _theme: Theme
var _info: PanelContainer
var _pos_label: Label
var _field_label: Label
var _lap_label: Label
var _time_label: Label
var _mode_label: Label
var _combat_box: HBoxContainer
var _front_icon: TextureRect
var _front_label: Label
var _rear_icon: TextureRect
var _rear_label: Label
## Cooldown bars under each weapon (fill = time until the slot is ready).
var _front_bar: ColorRect
var _rear_bar: ColorRect
var _wreck_label: Label
var _weapon_textures: Dictionary = {}
var _tower: VBoxContainer
var _tower_box: VBoxContainer
var _tower_panel: PanelContainer
var _tower_rows: Array = []
## Tower text size (smaller in a split-screen view).
var _row_font := 18
## Split-screen view: the compact tower sits in the view's bottom outer corner
## (away from the car at the centre and the info panel at the top).
var _split_view := false
var _tower_right_width := 0.0
## Human racers: id -> identity colour; _own_ids are the humans this HUD
## belongs to (row box highlight in the tower and results).
var _human_colors: Dictionary = {}
var _own_ids: Array[int] = []
## Spectator: the followed driver's id, the arrow buttons and row highlight style.
var _followed := -1
var _follow_controls: HBoxContainer
var _follow_prev: Button
var _follow_next: Button
var _highlight: StyleBoxFlat
var _no_highlight: StyleBoxEmpty
var _message: PanelContainer
var _message_box: VBoxContainer
var _banner: Label
var _banner_tween: Tween
## Results wait for the banner to fade before they appear.
var _message_waiting := false
## The results panel is up: the live tower and the DESTROYED countdown are
## hidden (the results supersede them; nothing duplicated or covered) and no
## banner is flashed over it.
var _results_up := false
var _tower_enabled := true
## Split-screen shared HUD: centre panels start below the players' info panels.
var _message_min_top := 0.0
var _message_tween: Tween
var _stars: Array[Texture2D] = []
var _car_textures: Dictionary = {}
var _full_names: Dictionary = {}
var _results_key := ""
var _menu_key := ""
var _net_label: Label
## Track theme name shown on the grid panel.
var track_name := ""
## Spectator race history (created by setup_history).
var history_panel: HistoryPanel


func setup(resolver: AssetResolver) -> void:
	_theme = HyperTheme.build(resolver)
	_stars = [resolver.get_texture(AssetCatalog.STAR_GOLD), resolver.get_texture(AssetCatalog.STAR_SILVER),
		resolver.get_texture(AssetCatalog.STAR_BRONZE)]
	var info := PanelContainer.new()
	_info = info
	info.theme = _theme
	info.position = Vector2(20, 16)
	info.custom_minimum_size = Vector2(250, 0)
	add_child(info)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	info.add_child(box)
	var pos_row := HBoxContainer.new()
	pos_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_pos_label = HyperTheme.label("P1", 44, HyperTheme.GOLD, 700)
	_field_label = HyperTheme.label("/ 10", 24, HyperTheme.CREAM_DIM, 600)
	_field_label.size_flags_vertical = Control.SIZE_SHRINK_END
	pos_row.add_child(_pos_label)
	pos_row.add_child(_field_label)
	box.add_child(pos_row)
	_lap_label = HyperTheme.label("LAP 1 / 3", 24, HyperTheme.CREAM, 600)
	_time_label = HyperTheme.label("00:00.00", 22, HyperTheme.CREAM, 500)
	_mode_label = HyperTheme.label("", 15, HyperTheme.CREAM_DIM, 500)
	for l in [_lap_label, _time_label, _mode_label]:
		box.add_child(l)

	_combat_box = HBoxContainer.new()
	_combat_box.add_theme_constant_override("separation", 14)
	box.add_child(_combat_box)
	_front_icon = _icon(Vector2(34, 22))
	_front_label = HyperTheme.label("", 18, HyperTheme.CREAM, 700)
	_rear_icon = _icon(Vector2(34, 22))
	_rear_label = HyperTheme.label("", 18, HyperTheme.CREAM, 700)
	_front_bar = ColorRect.new()
	_rear_bar = ColorRect.new()
	_combat_box.add_child(_weapon_slot("F", _front_icon, _front_label, _front_bar))
	_combat_box.add_child(_weapon_slot("R", _rear_icon, _rear_label, _rear_bar))
	_combat_box.visible = false
	_wreck_label = HyperTheme.label("", 44, HyperTheme.RED, 700)
	_wreck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wreck_label.size = Vector2(1280, 60)
	_wreck_label.position = Vector2(0, 470)
	_wreck_label.visible = false
	add_child(_wreck_label)
	_weapon_textures = weapon_icons(resolver)

	var tower_box := VBoxContainer.new()
	_tower_box = tower_box
	tower_box.position = Vector2(16, 226)
	tower_box.add_theme_constant_override("separation", 6)
	tower_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tower_box)
	# Translucent backing (the replaceable HUD panel, lighter) so the names
	# stay readable over road, barrier and every track variant.
	_tower_panel = PanelContainer.new()
	_tower_panel.theme = _theme
	_tower_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing: StyleBox = _theme.get_stylebox("panel", "PanelContainer").duplicate()
	backing.content_margin_left = 8
	backing.content_margin_right = 12
	backing.content_margin_top = 7
	backing.content_margin_bottom = 7
	_tower_panel.add_theme_stylebox_override("panel", backing)
	_tower_panel.self_modulate = Color(1, 1, 1, 0.78)
	tower_box.add_child(_tower_panel)
	_tower = VBoxContainer.new()
	_tower.add_theme_constant_override("separation", 1)
	_tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tower_panel.add_child(_tower)
	_highlight = StyleBoxFlat.new()
	_highlight.bg_color = Color(HyperTheme.GOLD, 0.28)
	_highlight.border_color = HyperTheme.GOLD
	_highlight.set_border_width_all(2)
	_highlight.set_corner_radius_all(6)
	_highlight.set_content_margin_all(1)
	_no_highlight = StyleBoxEmpty.new()
	_no_highlight.set_content_margin_all(1)
	_follow_controls = HBoxContainer.new()
	_follow_controls.theme = _theme
	_follow_controls.add_theme_constant_override("separation", 8)
	_follow_prev = _arrow_button("<", -1)
	_follow_next = _arrow_button(">", 1)
	_follow_controls.add_child(_follow_prev)
	_follow_controls.add_child(_follow_next)
	_follow_controls.visible = false
	tower_box.add_child(_follow_controls)

	_message = PanelContainer.new()
	_message.theme = _theme
	_message.visible = false
	add_child(_message)
	_message_box = VBoxContainer.new()
	_message_box.add_theme_constant_override("separation", 6)
	_message.add_child(_message_box)

	_net_label = HyperTheme.label("", 15, HyperTheme.CREAM_DIM, 600)
	_net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_net_label.size = Vector2(560, 22)
	_net_label.position = Vector2(1280 - 560 - 18, 690)
	_net_label.visible = false
	add_child(_net_label)
	_banner = HyperTheme.label("", 96, HyperTheme.GOLD, 700)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(1280, 140)
	_banner.position = Vector2(0, BANNER_Y)
	_banner.pivot_offset = Vector2(640, 70)
	_banner.modulate.a = 0.0
	add_child(_banner)


## Car icons and full names for the tower and results (keyed by racer id).
func set_field(car_textures: Dictionary, full_names: Dictionary) -> void:
	_car_textures = car_textures
	_full_names = full_names


func show_mode_select(mode: CarModel.ControlMode) -> void:
	show_menu(mode_name(mode))


## Mode menu shown on the grid before the start, with the Weapons ON / No Guns option.
func show_menu(choice: String, weapons: bool = false, laps: int = 3, style: int = WeaponRules.Style.CLASSIC, note: String = "") -> void:
	_mode_label.text = choice
	var key := choice + str(weapons) + str(laps) + str(style) + note
	if _menu_key == key and _message.visible:
		return
	_menu_key = key
	_results_key = ""
	set_results_up(false)
	_clear_message()
	var header := "GET READY" if track_name.is_empty() else "GET READY  -  %s" % track_name.to_upper()
	_message_box.add_child(_centered(HyperTheme.label(header, 22, HyperTheme.CREAM_DIM, 600)))
	_message_box.add_child(_centered(HyperTheme.label("<   %s   >" % choice, 34, HyperTheme.GOLD, 700)))
	_message_box.add_child(_centered(HyperTheme.label("%s     %s COMBAT     %d LAPS" % [weapons_text(weapons),
		WeaponRules.style_name(style), laps], 26, HyperTheme.RED if weapons else HyperTheme.CREAM, 700)))
	if not note.is_empty():
		_message_box.add_child(_centered(HyperTheme.label(note, 22, HyperTheme.GOLD, 700)))
	_message_box.add_child(_centered(HyperTheme.label("Left / Right: mode    Up / Down: weapons    C: combat style    Tab: laps    Fire: start    Esc: menu", 17, HyperTheme.CREAM_DIM, 500)))
	_present_message(Vector2(640, 0))


## Network races: small connection-quality line (bottom right); red when troubled.
func set_net_quality(text: String, bad: bool) -> void:
	_net_label.visible = not text.is_empty()
	_net_label.text = text
	_net_label.add_theme_color_override("font_color", HyperTheme.RED if bad else HyperTheme.CREAM_DIM)


## A short notice in the centre panel (e.g. a lost network connection).
func show_notice(title: String, text: String, footer: String) -> void:
	_menu_key = ""
	_results_key = ""
	set_results_up(false)
	_clear_message()
	_message_box.add_child(_centered(HyperTheme.label(title, 34, HyperTheme.RED, 700)))
	_message_box.add_child(_centered(HyperTheme.label(text, 22, HyperTheme.CREAM, 600)))
	_message_box.add_child(_centered(HyperTheme.label(footer, 17, HyperTheme.CREAM_DIM, 500)))
	_present_message(Vector2(640, 0))


static func weapons_text(on: bool) -> String:
	return "WEAPONS ON" if on else "NO GUNS"


## Player's weapons: icons + ammo + cooldown bars (0 = ready, 1 = just fired),
## and the DESTROYED countdown while wrecked.
func update_combat(enabled: bool, front: int, front_ammo: int, rear: int, rear_ammo: int, wreck_left: float,
		front_cooldown: float = 0.0, rear_cooldown: float = 0.0) -> void:
	_combat_box.visible = enabled
	_wreck_label.visible = enabled and wreck_left > 0.0 and not _results_up
	if not enabled:
		return
	_set_slot(_front_icon, _front_label, _front_bar, front, front_ammo, front_cooldown)
	_set_slot(_rear_icon, _rear_label, _rear_bar, rear, rear_ammo, rear_cooldown)
	_wreck_label.text = "DESTROYED  %.1f" % wreck_left


## Icon per weapon type (also used by the garage).
static func weapon_icons(resolver: AssetResolver) -> Dictionary:
	return {
		WeaponRules.Weapon.FRONT_MISSILE: resolver.get_texture(AssetCatalog.MISSILE),
		WeaponRules.Weapon.REAR_MISSILE: resolver.get_texture(AssetCatalog.MISSILE),
		WeaponRules.Weapon.HOMING_MISSILE: resolver.get_texture(AssetCatalog.HOMING_MISSILE),
		WeaponRules.Weapon.SUPER_MISSILE: resolver.get_texture(AssetCatalog.SUPER_MISSILE),
		WeaponRules.Weapon.MINE: _first_frame(resolver.get_texture(AssetCatalog.MINE), AssetCatalog.SPECS[AssetCatalog.MINE].frames),
	}


## First frame of a horizontal sprite strip (icons show one frame).
static func _first_frame(tex: Texture2D, frames: int) -> Texture2D:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(0, 0, tex.get_width() / float(frames), tex.get_height())
	return a


func _set_slot(icon: TextureRect, label: Label, bar: ColorRect, weapon: int, count: int, wait: float) -> void:
	var none := weapon == WeaponRules.Weapon.NONE
	icon.texture = null if none else _weapon_textures.get(weapon)
	icon.flip_h = weapon == WeaponRules.Weapon.REAR_MISSILE
	label.text = "-" if none else "x%d" % count
	label.add_theme_color_override("font_color", HyperTheme.CREAM if count > 0 else HyperTheme.CREAM_DIM)
	var ready := wait <= 0.0 and count > 0
	bar.size.x = 64.0 * (1.0 - clampf(wait, 0.0, 1.0)) if count > 0 else 0.0
	bar.color = HyperTheme.GOLD if ready else HyperTheme.RED


func _weapon_slot(tag: String, icon: TextureRect, label: Label, bar: ColorRect) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(HyperTheme.label(tag, 13, HyperTheme.CREAM_DIM, 700))
	row.add_child(icon)
	row.add_child(label)
	col.add_child(row)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.35)
	track.custom_minimum_size = Vector2(64, 5)
	bar.size = Vector2(64, 5)
	track.add_child(bar)
	col.add_child(track)
	return col


func _icon(min_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = min_size
	return t


func setup_history(resolver: AssetResolver, history: RaceHistory, car_textures: Dictionary, names: Dictionary) -> void:
	history_panel = HistoryPanel.new()
	history_panel.theme = _theme
	history_panel.position = Vector2(656, 16)
	history_panel.size = Vector2(604, 372)
	add_child(history_panel)
	history_panel.setup(resolver, history, car_textures, names)
	history_panel.visible = false
	# centre panels and banners draw above the history panel, never under it
	move_child(_message, -1)
	move_child(_banner, -1)


func hide_message() -> void:
	_message.visible = false
	_message_waiting = false
	set_results_up(false)
	_menu_key = ""
	_results_key = ""


## Spectator info panel: race number, leader's lap, race time, speed, who the camera follows.
func update_spectator(race_number: int, lap: int, lap_count: int, elapsed: float, speed_label: String, following: String, weapons: bool = false) -> void:
	_pos_label.text = "RACE %d" % race_number
	_field_label.text = ""
	_lap_label.text = "LAP %d / %d" % [lap, lap_count]
	_time_label.text = format_time(elapsed)
	_mode_label.text = "%s  %s   camera: %s" % [weapons_text(weapons), speed_label, following]


func show_racing(mode: CarModel.ControlMode) -> void:
	hide_message()
	_mode_label.text = mode_name(mode)


func update_race(lap: int, lap_count: int, elapsed: float, position: int = 1, field: int = 1) -> void:
	_pos_label.text = "P%d" % position
	_field_label.text = "/ %d" % field
	_lap_label.text = "LAP %d / %d" % [lap, lap_count]
	_time_label.text = format_time(elapsed)


## Live position tower (one row per car, player highlighted).
func update_tower(standings: Array[RacerState]) -> void:
	while _tower_rows.size() < standings.size():
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _no_highlight)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.gui_input.connect(_on_row_input.bind(panel))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		row.add_theme_constant_override("separation", 6 if _row_font >= 18 else 4)
		var pos := HyperTheme.label("", _row_font, HyperTheme.CREAM, 700)
		pos.custom_minimum_size = Vector2(_row_font * 1.5, 0)
		pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(_row_font * 1.9, _row_font * 1.12)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := HyperTheme.label("", _row_font, HyperTheme.CREAM, 600)
		name.custom_minimum_size = Vector2(_row_font * 3.9, 0)
		row.add_child(pos)
		row.add_child(icon)
		row.add_child(name)
		_tower.add_child(panel)
		_tower_rows.append([panel, pos, icon, name])
	for i in _tower_rows.size():
		var parts: Array = _tower_rows[i]
		var visible_row := i < standings.size()
		parts[0].visible = visible_row
		if not visible_row:
			continue
		var r := standings[i]
		parts[0].set_meta("racer_id", r.id)
		parts[1].text = str(i + 1)
		parts[2].texture = _car_textures.get(r.id)
		parts[3].text = r.display_name
		var followed: bool = _follow_controls.visible and r.id == _followed
		var col := HyperTheme.GOLD if r.is_player or followed else (HyperTheme.CREAM_DIM if r.is_finished() else HyperTheme.CREAM)
		var box: StyleBox = _highlight if followed else _no_highlight
		if _human_colors.has(r.id):
			col = _human_colors[r.id]
			if _own_ids.has(r.id):
				box = _row_highlight(col)
		parts[3].add_theme_color_override("font_color", col)
		parts[0].add_theme_stylebox_override("panel", box)
	if _split_view:
		var size := _tower_box.get_combined_minimum_size()
		_tower_box.position = Vector2(_tower_right_width - size.x - 12.0 if _tower_right_width > 0.0 else 12.0,
			720.0 - size.y - 12.0)


## Spectator follow controls: clickable rows, arrows and the highlighted
## driver. Off in normal races (rows are then plain, as before).
func set_follow(enabled: bool, followed_id: int) -> void:
	_follow_controls.visible = enabled
	_followed = followed_id
	for parts in _tower_rows:
		parts[0].mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		parts[0].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW


func _on_row_input(event: InputEvent, panel: PanelContainer) -> void:
	if not _follow_controls.visible or not panel.has_meta("racer_id"):
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		follow_requested.emit(int(panel.get_meta("racer_id")))
		panel.accept_event()


func _arrow_button(text: String, direction: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(52, 34)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBox = _theme.get_stylebox(state, "Button").duplicate()
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 2
		box.content_margin_bottom = 4
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(func() -> void: follow_step_requested.emit(direction))
	return b


func set_tower_visible(on: bool) -> void:
	_tower_enabled = on
	_tower_box.visible = _tower_enabled and not _results_up


## Results on screen (this HUD's or, for a split-screen view, the shared one):
## the race overlays (tower, DESTROYED countdown) step aside.
func set_results_up(on: bool) -> void:
	if on == _results_up:
		return
	_results_up = on
	_tower_box.visible = _tower_enabled and not on
	if on:
		_wreck_label.visible = false


func results_up() -> bool:
	return _results_up


## Human racers and their identity colours; own_ids are the humans this HUD
## belongs to (their rows get a highlight box in the tower and the results).
func set_humans(colors: Dictionary, own_ids: Array[int]) -> void:
	_human_colors = colors
	_own_ids = own_ids


## Box highlight for a human's row, in their identity colour.
static func _row_highlight(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color, 0.24)
	s.border_color = Color(color, 0.9)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(1)
	return s


## Two-player: a HUD for one player's half of the screen (info panel, weapons,
## DESTROYED countdown centred in the view, and a compact standings tower at
## the view's outer edge: left for the left view, right for the right one);
## the shared HUD keeps the menus, banners and results.
func configure_player_view(width: float, title: String, index: int = 0, right_edge: bool = false) -> void:
	_message.visible = false
	_banner.visible = false
	_wreck_label.size.x = width
	_mode_label.text = title
	_mode_label.add_theme_color_override("font_color", HyperTheme.player_color(index))
	_row_font = 14
	_split_view = true
	_tower_right_width = width if right_edge else 0.0


## The car icons and names of the field, shared from another HUD (split views).
func copy_field_from(other: Hud) -> void:
	set_field(other._car_textures, other._full_names)


## Split-screen shared HUD: centre panels (grid panel, results) start below
## the players' info panels at the top of each view.
func set_message_min_top(y: float) -> void:
	_message_min_top = y


## Split-screen shared HUD and spectating (history panel at the top): the
## banner sits low on the screen.
func set_banner_low(on: bool) -> void:
	_banner.position.y = BANNER_Y_SPLIT if on else BANNER_Y


func set_info_visible(on: bool) -> void:
	_info.visible = on


## Results card: podium stars, car icons, names with nicknames, time or gap.
func show_results(standings: Array[RacerState], footer: String = "Fire to race again (reversed grid)") -> void:
	var key := footer
	for r in standings:
		key += "|%d:%d:%.3f" % [r.id, r.finish_position, r.finish_time]
	if key == _results_key and _message.visible:
		return
	# Already on screen (another car finished, a footer or the exact network
	# times arrived): update in place, without fading out and in again.
	var update := _results_up and _message.visible and not _results_key.is_empty()
	_results_key = key
	set_results_up(true)
	_menu_key = ""
	_clear_message()
	var laps: int = standings[0].tracker.lap_count if not standings.is_empty() else 0
	_message_box.add_child(_centered(HyperTheme.label("RESULTS  -  %d LAPS" % laps, 34, HyperTheme.GOLD, 700)))
	# One row per car (same columns as before); the HUD's own human rows get a
	# box in their identity colour, other humans their colour.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	_message_box.add_child(rows)
	var names: Array[Label] = []
	var winner_time := standings[0].finish_time if not standings.is_empty() and standings[0].is_finished() else -1.0
	for i in standings.size():
		var r := standings[i]
		var color: Color = _human_colors.get(r.id, HyperTheme.GOLD if r.is_player else HyperTheme.CREAM)
		var own := _own_ids.has(r.id) or (_own_ids.is_empty() and r.is_player)
		var panel := PanelContainer.new()
		var box: StyleBox = _row_highlight(color) if own else StyleBoxEmpty.new()
		box.content_margin_left = 4
		box.content_margin_right = 8
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		panel.add_theme_stylebox_override("panel", box)
		rows.add_child(panel)
		var grid := HBoxContainer.new()
		grid.add_theme_constant_override("separation", 14)
		panel.add_child(grid)
		grid.add_child(_position_marker(i + 1))
		var icon := TextureRect.new()
		icon.texture = _car_textures.get(r.id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(44, 26)
		grid.add_child(icon)
		var name: String = _full_names.get(r.id, r.display_name)
		var name_label := HyperTheme.label(name, 20, color, 700 if own else 600)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.append(name_label)
		grid.add_child(name_label)
		var time := "running"
		if r.is_finished():
			if r.finish_time < 0.0:
				time = "classified"
			elif i == 0 or winner_time < 0.0:
				time = format_time(r.finish_time)
			else:
				time = "+%.2f" % (r.finish_time - winner_time)
		var t := HyperTheme.label(time, 20, HyperTheme.CREAM if r.is_finished() else HyperTheme.CREAM_DIM, 500)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.custom_minimum_size = Vector2(110, 0)
		grid.add_child(t)
	var name_width := 0.0
	for l in names:
		name_width = maxf(name_width, l.get_combined_minimum_size().x)
	for l in names:
		l.custom_minimum_size.x = name_width
	_message_box.add_child(_centered(HyperTheme.label(footer, 17, HyperTheme.CREAM_DIM, 500)))
	_present_message(Vector2(640, 0), true, update)


## Plain-text results (kept for logs and tests).
static func results_text(standings: Array[RacerState], footer: String = "Fire to race again (reversed grid)") -> String:
	var lines := PackedStringArray(["RESULTS"])
	for i in standings.size():
		var r := standings[i]
		var time := "running"
		if r.is_finished():
			time = format_time(r.finish_time) if r.finish_time >= 0.0 else "classified"
		var mark := "  <" if r.is_player else ""
		lines.append("%d.  %s   %s%s" % [i + 1, r.display_name, time, mark])
	lines.append(footer)
	return "\n".join(lines)


## Big animated banner ("GO!", "FINISH!"). Purely visual. Results waiting
## for it appear once it has faded.
func flash_banner(text: String, color: Color = HyperTheme.GOLD, hold: float = BANNER_HOLD) -> void:
	if _results_up and _message.visible:
		return  # never over the results (e.g. a late finisher after the stuck-player net)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	_banner_tween = tw
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tw.finished.connect(_release_message)


func banner_showing() -> bool:
	return _banner_tween != null and _banner_tween.is_valid() and _banner_tween.is_running()


static func mode_name(mode: CarModel.ControlMode) -> String:
	return "FIRE TO ACCELERATE" if mode == CarModel.ControlMode.FIRE_TO_ACCELERATE else "FIRE TO BRAKE"


static func format_time(seconds: float) -> String:
	var total_ms := int(round(seconds * 1000.0))
	return "%02d:%02d.%02d" % [total_ms / 60000, (total_ms / 1000) % 60, (total_ms % 1000) / 10]


func _position_marker(position: int) -> Control:
	if position >= 1 and position <= 3:
		var star := TextureRect.new()
		star.texture = _stars[position - 1]
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(30, 26)
		return star
	var l := HyperTheme.label(str(position), 20, HyperTheme.CREAM, 700)
	l.custom_minimum_size = Vector2(30, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _clear_message() -> void:
	for c in _message_box.get_children():
		c.free()


## Centres the panel on screen and fades it in; with after_banner, only once
## a GO! / FINISH! banner still on screen has faded (never on top of it). An
## in-place update keeps the current fade state.
func _present_message(_anchor: Vector2, after_banner: bool = false, update: bool = false) -> void:
	_message.visible = true
	_message.reset_size()
	_message.size = _message.get_combined_minimum_size()
	_message.position = _message_position(_message.size)
	if update:
		return
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()  # an earlier panel's fade-in must not reveal this one
	_message.modulate.a = 0.0
	_message_waiting = after_banner and banner_showing()
	if not _message_waiting:
		_fade_in_message()


## Centred, but clear of what else is on screen: below the split-screen info
## panels, and beside the spectator history panel when it fits there (the
## results), so neither hides the other.
func _message_position(size: Vector2) -> Vector2:
	var screen := Vector2(1280, 720)
	var pos := (screen - size) * 0.5
	pos.y = maxf(pos.y, _message_min_top)
	if history_panel != null and history_panel.visible:
		var room := history_panel.position.x - 16.0
		if size.x <= room - 16.0:
			pos.x = (room - size.x) * 0.5 + 8.0
			if _info.visible:
				pos.y = maxf(pos.y, _info.position.y + _info.size.y + 12.0)
	pos.y = minf(pos.y, screen.y - size.y - 8.0)
	return pos


func _release_message() -> void:
	if _message_waiting:
		_message_waiting = false
		if _message.visible:
			_fade_in_message()


func _fade_in_message() -> void:
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.2)
