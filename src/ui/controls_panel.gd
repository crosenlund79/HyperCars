class_name ControlsPanel
extends PanelContainer
## Remappable controls (keyboard and controller, ControlBindings) and short
## how-to-play help. Choose a slot, then press the new key or pad input
## (Esc cancels); clashes are refused with a message.

signal closed

const ROWS := [
	["RACING", ""],
	["Fire to Accelerate", "Hold Fire to accelerate, release to brake"],
	["Fire to Brake", "Accelerates by itself, hold Fire to brake hard"],
	["Weapons / style / laps", "Up / Down, C and Tab on the grid panel"],
	["Lighting pilot", "L (dusk lighting on / off, experiment)"],
	["Back to menu", "Esc on the grid or results; Enter confirms results and menus"],
	["TWO PLAYERS", ""],
	["Join", "Race > Two players: each presses Cross / A (keyboard: Space)"],
	["Drive", "Own controller or the keyboard, with the bindings on the left"],
	["LAN / online", "Race > Two players: LAN / online. Host shares its address; see docs/NETWORK_PLAY.md"],
	["SPECTATING", ""],
	["Follow a driver", "Click a name in the standings, or the < > arrows (grid order)"],
	["History / Counts", "Tab (Skip / history)"],
	["Hide / show panel", "H"],
	["Scroll history", "Steer left / right"],
	["Stop spectating", "Back"],
	["THE RACE", ""],
	["Laps", "Count only when every checkpoint is passed in order"],
	["Grid", "Next race starts from the reversed result: the winner starts last"],
	["Garage race", "Results: Enter = garage, Tab = skip shopping; top five win prize money"],
]

var _back: Button
var _defaults: Button
var _status: Label
## [action, kind] -> its button.
var _slots := {}
## The slot waiting for a new input ([action, kind]), empty when none.
var waiting: Array = []


func setup() -> void:
	custom_minimum_size = Vector2(1180, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := HyperTheme.label("CONTROLS & HELP", 32, HyperTheme.GOLD, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	box.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	var map := GridContainer.new()
	map.columns = 3
	map.add_theme_constant_override("h_separation", 10)
	map.add_theme_constant_override("v_separation", 3)
	left.add_child(map)
	for h in ["ACTION", "KEYBOARD", "CONTROLLER"]:
		map.add_child(HyperTheme.label(h, 16, HyperTheme.GOLD, 700))
	for a in ControlBindings.ACTIONS:
		map.add_child(HyperTheme.label(a[1], 16, HyperTheme.CREAM, 600))
		for kind in [ControlBindings.KEYBOARD, ControlBindings.PAD]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(200, 30)
			b.add_theme_font_size_override("font_size", 14)
			b.clip_text = true
			b.pressed.connect(_listen.bind(a[0], kind))
			map.add_child(b)
			_slots[[a[0], kind]] = b
	_status = HyperTheme.label("", 15, HyperTheme.CREAM_DIM, 500)
	_status.custom_minimum_size = Vector2(560, 44)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status)
	_defaults = Button.new()
	_defaults.text = "RESTORE DEFAULTS"
	_defaults.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_defaults.pressed.connect(restore_defaults)
	left.add_child(_defaults)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 0)
	cols.add_child(grid)
	for row in ROWS:
		var heading: bool = String(row[1]).is_empty()
		var a := HyperTheme.label(row[0], 14, HyperTheme.GOLD if heading else HyperTheme.CREAM, 700 if heading else 600)
		grid.add_child(a)
		var t := HyperTheme.label(row[1], 14, HyperTheme.CREAM, 500)
		t.custom_minimum_size = Vector2(400, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(t)
	_back = Button.new()
	_back.text = "BACK"
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: closed.emit())
	box.add_child(_back)
	refresh()


func focus_first() -> void:
	refresh()
	_back.grab_focus()


func refresh() -> void:
	for key in _slots:
		_slots[key].text = ControlBindings.describe(key[0], key[1])
	if waiting.is_empty():
		_status.text = "Choose a slot, then press the new key or controller input. Enter always confirms and Esc always goes back."
		_status.add_theme_color_override("font_color", HyperTheme.CREAM_DIM)


## Waits for the next input for one slot.
func _listen(action: String, kind: String) -> void:
	waiting = [action, kind]
	_slots[waiting].text = "press..."
	_status.text = "%s: press the new %s (Esc cancels)." % [ControlBindings.label_of(action),
		"key" if kind == ControlBindings.KEYBOARD else "controller button or stick direction"]
	_status.add_theme_color_override("font_color", HyperTheme.GOLD)


func _input(event: InputEvent) -> void:
	if waiting.is_empty() or not visible:
		return
	var kind := ""
	if event is InputEventKey and event.pressed and not event.echo:
		kind = ControlBindings.KEYBOARD
	elif event is InputEventJoypadButton and event.pressed:
		kind = ControlBindings.PAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		kind = ControlBindings.PAD
	if kind == "":
		return
	get_viewport().set_input_as_handled()
	var slot: Array = waiting
	waiting = []
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE and slot[0] != PlayerControls.BACK:
		refresh()
		return
	if kind != slot[1]:
		refresh()
		_status.text = "That was a %s input; this slot needs a %s." % [
			"keyboard" if kind == ControlBindings.KEYBOARD else "controller", "key" if slot[1] == ControlBindings.KEYBOARD else "controller input"]
		_status.add_theme_color_override("font_color", Color("ff8a6a"))
		_slots[slot].grab_focus()
		return
	var err := ControlBindings.assign(slot[0], event)
	refresh()
	if err != "":
		_status.text = err
		_status.add_theme_color_override("font_color", Color("ff8a6a"))
	else:
		ControlBindings.save()
		_status.text = "%s: %s." % [ControlBindings.label_of(slot[0]), ControlBindings.describe(slot[0], slot[1])]
		_status.add_theme_color_override("font_color", HyperTheme.GOLD)
	_slots[slot].grab_focus()


func restore_defaults() -> void:
	waiting = []
	ControlBindings.restore_defaults()
	refresh()
	_status.text = "Default controls restored."
	_status.add_theme_color_override("font_color", HyperTheme.GOLD)
