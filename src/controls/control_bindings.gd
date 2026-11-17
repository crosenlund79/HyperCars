class_name ControlBindings
extends RefCounted
## Remappable controls on top of Godot's InputMap: one keyboard key and one
## controller input per action, chosen on the CONTROLS screen, saved to
## user://controls.cfg and applied at start-up. Couch players copy these
## bindings onto their own device (PlayerControls.ensure_player_actions).
##
## Safety: an input belongs to one action only (a clash is refused with a
## message, so Fire can never become Confirm); Enter / keypad Enter always
## confirm and Esc always goes back (reserved, they cannot be taken away or
## given to another action).

const PATH := "user://controls.cfg"

## [action, label] in screen order.
const ACTIONS := [
	[PlayerControls.STEER_LEFT, "Steer left"],
	[PlayerControls.STEER_RIGHT, "Steer right"],
	[PlayerControls.FIRE, "Fire"],
	[PlayerControls.FIRE_FRONT, "Front weapon"],
	[PlayerControls.FIRE_REAR, "Rear weapon"],
	[PlayerControls.CONFIRM, "Confirm (menus)"],
	[PlayerControls.BACK, "Back / race menu"],
	[PlayerControls.HISTORY_VIEW, "Skip / history (Tab)"],
	[PlayerControls.SIM_SPEED, "Spectator speed"],
]
const KEYBOARD := "key"
const PAD := "pad"
## Always on these actions, never on another one.
const RESERVED := {KEY_ENTER: PlayerControls.CONFIRM, KEY_KP_ENTER: PlayerControls.CONFIRM, KEY_ESCAPE: PlayerControls.BACK}

static var path := PATH


static func label_of(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action


static func is_remappable(action: String) -> bool:
	for a in ACTIONS:
		if a[0] == action:
			return true
	return false


## The events of one kind (KEYBOARD or PAD) bound to an action.
static func events(action: String, kind: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for e in InputMap.action_get_events(action):
		if _kind_of(e) == kind:
			out.append(e)
	return out


## "Left / A", "D-pad Left / Left stick left" ...
static func describe(action: String, kind: String) -> String:
	var names := PackedStringArray()
	for e in events(action, kind):
		names.append(event_name(e))
	return " / ".join(names) if not names.is_empty() else "-"


static func event_name(e: InputEvent) -> String:
	if e is InputEventKey:
		var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		return OS.get_keycode_string(code)
	if e is InputEventJoypadButton:
		var names := {JOY_BUTTON_A: "Pad A / Cross", JOY_BUTTON_B: "Pad B / Circle", JOY_BUTTON_X: "Pad X / Square",
			JOY_BUTTON_Y: "Pad Y / Triangle", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Select",
			JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_DPAD_UP: "D-pad up",
			JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
			JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"}
		return names.get(e.button_index, "Pad button %d" % e.button_index)
	if e is InputEventJoypadMotion:
		var axes := {JOY_AXIS_LEFT_X: ["L stick left", "L stick right"], JOY_AXIS_LEFT_Y: ["L stick up", "L stick down"],
			JOY_AXIS_RIGHT_X: ["R stick left", "R stick right"], JOY_AXIS_RIGHT_Y: ["R stick up", "R stick down"],
			JOY_AXIS_TRIGGER_LEFT: ["L2", "L2"], JOY_AXIS_TRIGGER_RIGHT: ["R2", "R2"]}
		var pair: Array = axes.get(e.axis, ["Axis %d-" % e.axis, "Axis %d+" % e.axis])
		return pair[0] if e.axis_value < 0.0 else pair[1]
	return "?"


## Binds `event` as the action's input of its kind (replacing that kind's
## other inputs; Enter / Esc stay on Confirm / Back). Returns "" or why not.
static func assign(action: String, event: InputEvent) -> String:
	var kind := _kind_of(event)
	if kind == "" or not is_remappable(action):
		return "That input cannot be used."
	var clean := _clean(event)
	if clean is InputEventKey:
		var reserved: String = RESERVED.get(clean.physical_keycode, "")
		if reserved != "":
			if reserved == action:
				return ""  # already there, always
			return "%s is reserved for %s." % [event_name(clean), label_of(reserved)]
	for a in ACTIONS:
		if a[0] != action and _has(a[0], clean):
			return "%s is already used for %s." % [event_name(clean), a[1]]
	for e in events(action, kind):
		if not _is_reserved(e):
			InputMap.action_erase_event(action, e)
	if not _has(action, clean):
		InputMap.action_add_event(action, clean)
	return ""


## Restores the default bindings (and forgets the saved ones).
static func restore_defaults() -> void:
	for a in ACTIONS:
		if InputMap.has_action(a[0]):
			InputMap.erase_action(a[0])
	PlayerControls.ensure_actions()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func save() -> void:
	var cfg := ConfigFile.new()
	for a in ACTIONS:
		var list := []
		for e in InputMap.action_get_events(a[0]):
			list.append(_to_dict(e))
		cfg.set_value("bindings", a[0], list)
	cfg.save(path)


## Applies saved bindings (after PlayerControls.ensure_actions). Unknown or
## broken entries are ignored; Enter / Esc are put back if missing.
static func load_saved() -> void:
	PlayerControls.ensure_actions()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for a in ACTIONS:
		var list = cfg.get_value("bindings", a[0], null)
		if not (list is Array) or (list as Array).is_empty():
			continue
		var parsed: Array[InputEvent] = []
		for d in list:
			var e := _from_dict(d)
			if e != null:
				parsed.append(e)
		if parsed.is_empty():
			continue
		InputMap.action_erase_events(a[0])
		for e in parsed:
			InputMap.action_add_event(a[0], e)
	for code in RESERVED:
		if not _has(RESERVED[code], PlayerControls._key(code)):
			InputMap.action_add_event(RESERVED[code], PlayerControls._key(code))


static func _kind_of(e: InputEvent) -> String:
	if e is InputEventKey:
		return KEYBOARD
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		return PAD
	return ""


## A device-independent copy (device 0 for pads, physical key code for keys).
static func _clean(e: InputEvent) -> InputEvent:
	if e is InputEventKey:
		var code: Key = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		return PlayerControls._key(code)
	if e is InputEventJoypadButton:
		return PlayerControls._joy_button(e.button_index)
	if e is InputEventJoypadMotion:
		return PlayerControls._joy_axis(e.axis, -1.0 if e.axis_value < 0.0 else 1.0)
	return e


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func _has(action: String, e: InputEvent) -> bool:
	for f in InputMap.action_get_events(action):
		if _same(f, e):
			return true
	return false


static func _is_reserved(e: InputEvent) -> bool:
	return e is InputEventKey and RESERVED.has(e.physical_keycode)


static func _to_dict(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"key": int(e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode)}
	if e is InputEventJoypadButton:
		return {"button": e.button_index}
	if e is InputEventJoypadMotion:
		return {"axis": e.axis, "value": signf(e.axis_value)}
	return {}


static func _from_dict(d) -> InputEvent:
	if not (d is Dictionary):
		return null
	if d.has("key"):
		return PlayerControls._key(int(d.key))
	if d.has("button") and int(d.button) >= 0 and int(d.button) < JOY_BUTTON_MAX:
		return PlayerControls._joy_button(int(d.button))
	if d.has("axis") and int(d.axis) >= 0 and int(d.axis) < JOY_AXIS_MAX:
		return PlayerControls._joy_axis(int(d.axis), -1.0 if float(d.get("value", 1.0)) < 0.0 else 1.0)
	return null
