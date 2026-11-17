class_name ChampionshipScreen
extends CanvasLayer
## Between championship rounds: the cumulative standings (points, this round's
## result), the next round's circuit, biome and time of day with the rotating
## circuit preview, and CONTINUE / ABANDON. After the last round: the final
## standings, the champion and - when the player won - the car reward.
## Presentation only: Championship holds the rules, the game the flow.

signal continue_requested
signal abandon_requested
## After the final round: back to the main menu.
signal done

const ROW_H := 30

var _resolver: AssetResolver
var _root: Control
var _title: Label
var _sub: Label
var _rows: VBoxContainer
var _next_title: Label
var _next_text: Label
var _preview: CircuitPreview
var _reward: Label
var _reward_car: TextureRect
var _continue: Button
var _abandon: Button
var _final := false
## Racing for Keeps: what abandoning costs ("" = nothing); ABANDON asks twice.
var warning := ""
var _confirming := false
var _hint: Label
var _icons := {}


func setup(resolver: AssetResolver) -> void:
	_resolver = resolver
	layer = 20
	_root = Control.new()
	_root.theme = HyperTheme.build(resolver)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := TextureRect.new()
	bg.texture = resolver.get_texture(AssetCatalog.GARAGE_BACKDROP)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(1280, 720)
	_root.add_child(bg)
	_title = HyperTheme.label("", 46, HyperTheme.GOLD, 700)
	_title.position = Vector2(40, 30)
	_root.add_child(_title)
	_sub = HyperTheme.label("", 20, HyperTheme.CREAM, 600)
	_sub.position = Vector2(42, 88)
	_root.add_child(_sub)

	var table := PanelContainer.new()
	table.position = Vector2(30, 126)
	table.custom_minimum_size = Vector2(640, 470)
	_root.add_child(table)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 2)
	table.add_child(tbox)
	tbox.add_child(_row_box(["POS", "", "DRIVER", "LAST", "WINS", "PTS"], true))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	tbox.add_child(_rows)

	var side := PanelContainer.new()
	side.position = Vector2(690, 126)
	side.custom_minimum_size = Vector2(560, 470)
	_root.add_child(side)
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 6)
	side.add_child(sbox)
	_next_title = HyperTheme.label("", 24, HyperTheme.GOLD, 700)
	sbox.add_child(_next_title)
	_next_text = HyperTheme.label("", 19, HyperTheme.CREAM, 600)
	_next_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_text.custom_minimum_size = Vector2(520, 0)
	sbox.add_child(_next_text)
	_preview = CircuitPreview.new()
	_preview.custom_minimum_size = Vector2(520, 300)
	sbox.add_child(_preview)
	_reward = HyperTheme.label("", 26, HyperTheme.GOLD, 700)
	_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.custom_minimum_size = Vector2(520, 0)
	sbox.add_child(_reward)
	_reward_car = TextureRect.new()
	_reward_car.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reward_car.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reward_car.custom_minimum_size = Vector2(520, 150)
	sbox.add_child(_reward_car)

	var buttons := HBoxContainer.new()
	buttons.position = Vector2(690, 612)
	buttons.add_theme_constant_override("separation", 16)
	_root.add_child(buttons)
	_continue = _button("CONTINUE", func() -> void: _on_continue())
	_abandon = _button("ABANDON", _on_abandon)
	buttons.add_child(_continue)
	buttons.add_child(_abandon)
	_hint = HyperTheme.label("", 16, HyperTheme.CREAM_DIM, 500)
	_hint.position = Vector2(34, 640)
	_root.add_child(_hint)
	visible = false


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 52)
	b.pressed.connect(action)
	b.mouse_entered.connect(b.grab_focus)
	return b


## One table row: position, car icon, driver, last round, wins, points.
func _row_box(cells: Array, header: bool, icon: Texture2D = null, color: Color = HyperTheme.CREAM) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(620, ROW_H)
	row.add_theme_constant_override("separation", 10)
	var widths := [54, 52, 280, 80, 60, 60]
	for k in cells.size():
		if k == 1 and not header:
			var t := TextureRect.new()
			t.texture = icon
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(widths[k], ROW_H)
			row.add_child(t)
			continue
		var l := HyperTheme.label(str(cells[k]), 17 if header else 20, HyperTheme.GOLD if header else color, 700 if header else 600)
		l.custom_minimum_size = Vector2(widths[k], ROW_H)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if k >= 3:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(l)
	return row


## icons: racer id -> car picture (the cars as they raced).
func set_icons(icons: Dictionary) -> void:
	_icons = icons


## Standings after a round. reward: the final message ("" = none yet).
## reward_car: the won (or lost) car's picture, or null.
func show_standings(champ: Championship, reward: String = "", reward_car: Texture2D = null) -> void:
	_final = champ.finished()
	var done_rounds := champ.results.size()
	_title.text = "%s  -  %s" % [champ.schedule.title.to_upper(), "FINAL STANDINGS" if _final else "STANDINGS"]
	_sub.text = "After round %d of %d" % [done_rounds, champ.schedule.round_count()]
	for c in _rows.get_children():
		c.queue_free()
	var order := champ.standings()
	for k in order.size():
		var id: int = order[k]
		var last := champ.position_in(done_rounds - 1, id) if done_rounds > 0 else 0
		var name := "YOU" if id == Championship.PLAYER else RivalRoster.full_name(id)
		var color := HyperTheme.GOLD if id == Championship.PLAYER else HyperTheme.CREAM
		_rows.add_child(_row_box([str(k + 1), "", name, ("P%d" % last) if last > 0 else "DNF",
			str(champ.wins(id)), str(champ.points[id])], false, _icons.get(id), color))
	if _final:
		var winner := champ.champion()
		_next_title.text = "CHAMPION:  %s" % ("YOU!" if winner == Championship.PLAYER else RivalRoster.full_name(winner).to_upper())
		_next_text.text = "%d points from %d rounds." % [champ.points[winner], champ.schedule.round_count()]
		_preview.visible = false
		_reward.text = reward
		_reward.visible = reward != ""
		_reward_car.texture = reward_car
		_reward_car.visible = reward_car != null
		_continue.text = "MAIN MENU"
		_abandon.visible = false
	else:
		var r := champ.next_round()
		_next_title.text = ("NEXT:  THE GRAND FINAL  -  ROUND %d OF %d" if r.get("final", false) else "NEXT:  ROUND %d OF %d") % [done_rounds + 1, champ.schedule.round_count()]
		_next_text.text = ChampionshipScreen.round_text(r)
		_preview.visible = true
		_preview.show_circuit(DevLayouts.load_layout(r.layout), r.variant, r.night)
		_reward.visible = false
		_reward_car.visible = false
		_continue.text = "START THE FINAL" if r.get("final", false) else "START ROUND %d" % (done_rounds + 1)
		_abandon.visible = true
	_hint.text = "Enter / Esc: main menu" if _final else "Enter: next round      Esc: abandon the championship"
	_confirming = false
	_abandon.text = "ABANDON"
	if not _final and warning != "":
		_sub.text += "      %s" % warning
		_sub.add_theme_color_override("font_color", Color("ff8a6a"))
	else:
		_sub.remove_theme_color_override("font_color")
	visible = true
	_continue.grab_focus()


## "KESTREL RIDGE  -  Winter  -  NIGHT  -  3 laps"
static func round_text(r: Dictionary) -> String:
	return "%s\n%s  -  %s  -  %d laps" % [DevLayouts.display_name(r.layout).to_upper(),
		TrackTheme.load_variant(r.variant).display_name, "NIGHT" if r.night else "DAY", r.laps]


func _on_abandon() -> void:
	if warning != "" and not _confirming:
		_confirming = true
		_abandon.text = "CONFIRM FORFEIT"
		_abandon.grab_focus()
		return
	abandon_requested.emit()


func close() -> void:
	visible = false
	for b in [_continue, _abandon]:
		if b.has_focus():
			b.release_focus()


func _on_continue() -> void:
	if _final:
		done.emit()
	else:
		continue_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(PlayerControls.BACK):
		get_viewport().set_input_as_handled()
		if _final:
			done.emit()
		else:
			_on_abandon()
	elif event.is_action_pressed(PlayerControls.CONFIRM) and not (_continue.has_focus() or _abandon.has_focus()):
		get_viewport().set_input_as_handled()
		_on_continue()
