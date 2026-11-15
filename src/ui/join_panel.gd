class_name JoinPanel
extends PanelContainer
## Two-player controller assignment: "press a button to join". The first
## device to press Cross / A (or Space / Enter on the keyboard) becomes
## Player 1, the next different device Player 2. Circle / B (or Esc) removes a
## joined player, or leaves when nobody has joined. With both joined, either
## player presses Cross / A (Space) again to start.

signal confirmed(devices: Array[int])
signal closed

var devices: Array[int] = []
## Listening only between open() and confirmation: the panel keeps visible=true
## while the whole title layer is hidden, so visibility alone is not enough.
var _active := false
var _slots: Array[Label] = []
var _hint: Label


func setup() -> void:
	custom_minimum_size = Vector2(760, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := HyperTheme.label("TWO PLAYERS - SPLIT SCREEN", 32, HyperTheme.GOLD, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for n in 2:
		var l := HyperTheme.label("", 24, HyperTheme.CREAM, 600)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		_slots.append(l)
	_hint = HyperTheme.label("", 17, HyperTheme.CREAM_DIM, 500)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)


func open() -> void:
	devices.clear()
	_active = true
	_refresh()


func _input(event: InputEvent) -> void:
	if not _active or not is_visible_in_tree():
		return
	var device := -2
	var cancel := false
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_B:
			cancel = true
			device = jb.device
		elif jb.button_index == JOY_BUTTON_A or jb.button_index == JOY_BUTTON_START:
			device = jb.device
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			cancel = true
			device = PlayerControls.KEYBOARD
		elif key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			device = PlayerControls.KEYBOARD
	if device == -2:
		return
	get_viewport().set_input_as_handled()
	press(device, cancel)


## One press from a device (also used by tests).
func press(device: int, cancel: bool = false) -> void:
	if not _active:
		return
	if cancel:
		if devices.has(device):
			devices.erase(device)
		elif devices.is_empty():
			_active = false
			closed.emit()
			return
	elif devices.has(device):
		if devices.size() == 2:
			_active = false  # exactly one start per deliberate confirmation
			confirmed.emit(devices.duplicate())
			return
	elif devices.size() < 2:
		devices.append(device)
	_refresh()


static func device_name(device: int) -> String:
	if device == PlayerControls.KEYBOARD:
		return "Keyboard"
	var n := Input.get_joy_name(device)
	return "%s (pad %d)" % [n if not n.is_empty() else "Controller", device]


func _refresh() -> void:
	for n in 2:
		var joined := n < devices.size()
		_slots[n].text = "PLAYER %d:  %s" % [n + 1, device_name(devices[n]) if joined else "press Cross / A to join"]
		_slots[n].add_theme_color_override("font_color", HyperTheme.GOLD if joined else HyperTheme.CREAM_DIM)
	_hint.text = "Both ready: press Cross / A again to continue    Circle / B: leave" if devices.size() == 2 \
		else "Keyboard: Space joins one player    Circle / B or Esc: back"
