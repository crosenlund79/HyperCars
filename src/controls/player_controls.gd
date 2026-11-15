class_name PlayerControls
extends RefCounted
## Joystick-style controls for one player: left/right steer, one fire button,
## joystick forward / backwards fire the front / rear weapon (original manual).
## Actions are only created if the project does not already define them, so they
## can be rebound in Project Settings > Input Map.

const STEER_LEFT := "steer_left"
const STEER_RIGHT := "steer_right"
const FIRE := "fire"
## Joystick forward / backwards: front / rear weapon (M3).
const FIRE_FRONT := "fire_front"
const FIRE_REAR := "fire_rear"
## Spectator mode only: switch history view, toggle simulation speed, leave.
const HISTORY_VIEW := "history_view"
const SIM_SPEED := "sim_speed"
const BACK := "back"
## Spectator: hide/show the race history panel.
const TOGGLE_PANEL := "toggle_panel"
## Lighting pilot on / off (presentation only).
const TOGGLE_LIGHTING := "toggle_lighting"
## Grid panel: Classic / Tactical combat style.
const TOGGLE_STYLE := "toggle_style"
const STICK_DEADZONE := 0.5
## Device id for a player on the keyboard (two-player assignment).
const KEYBOARD := -1
## Per-player driving actions (prefix + name) for two-player races.
const PLAYER_ACTIONS: Array[String] = [STEER_LEFT, STEER_RIGHT, FIRE, FIRE_FRONT, FIRE_REAR, BACK, HISTORY_VIEW, TOGGLE_STYLE]


## Prefix of player n's own actions (two-player races), e.g. "p2_".
static func player_prefix(player_number: int) -> String:
	return "p%d_" % player_number


## (Re)binds player n's driving actions to one device only: a joypad id, or
## KEYBOARD. Joypad events carry the device id, so two pads never share input.
static func ensure_player_actions(player_number: int, device: int) -> String:
	var prefix := player_prefix(player_number)
	for a in PLAYER_ACTIONS:
		if InputMap.has_action(prefix + a):
			InputMap.erase_action(prefix + a)
		InputMap.add_action(prefix + a, STICK_DEADZONE)
	if device == KEYBOARD:
		_bind(prefix + STEER_LEFT, [_key(KEY_LEFT), _key(KEY_A)])
		_bind(prefix + STEER_RIGHT, [_key(KEY_RIGHT), _key(KEY_D)])
		_bind(prefix + FIRE, [_key(KEY_SPACE), _key(KEY_CTRL)])
		_bind(prefix + FIRE_FRONT, [_key(KEY_UP), _key(KEY_W)])
		_bind(prefix + FIRE_REAR, [_key(KEY_DOWN), _key(KEY_S)])
		_bind(prefix + BACK, [_key(KEY_ESCAPE)])
		_bind(prefix + HISTORY_VIEW, [_key(KEY_TAB)])
		_bind(prefix + TOGGLE_STYLE, [_key(KEY_C)])
	else:
		_bind(prefix + STEER_LEFT, [_joy_button(JOY_BUTTON_DPAD_LEFT, device), _joy_axis(JOY_AXIS_LEFT_X, -1.0, device)])
		_bind(prefix + STEER_RIGHT, [_joy_button(JOY_BUTTON_DPAD_RIGHT, device), _joy_axis(JOY_AXIS_LEFT_X, 1.0, device)])
		_bind(prefix + FIRE, [_joy_button(JOY_BUTTON_A, device)])
		_bind(prefix + FIRE_FRONT, [_joy_button(JOY_BUTTON_DPAD_UP, device), _joy_axis(JOY_AXIS_LEFT_Y, -1.0, device)])
		_bind(prefix + FIRE_REAR, [_joy_button(JOY_BUTTON_DPAD_DOWN, device), _joy_axis(JOY_AXIS_LEFT_Y, 1.0, device)])
		_bind(prefix + BACK, [_joy_button(JOY_BUTTON_B, device)])
		_bind(prefix + HISTORY_VIEW, [_joy_button(JOY_BUTTON_Y, device)])
		_bind(prefix + TOGGLE_STYLE, [_joy_button(JOY_BUTTON_RIGHT_SHOULDER, device)])
	return prefix


static func _bind(action: String, events: Array) -> void:
	for e in events:
		InputMap.action_add_event(action, e)


static func ensure_actions() -> void:
	_add(STEER_LEFT, [_key(KEY_LEFT), _key(KEY_A), _joy_button(JOY_BUTTON_DPAD_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(STEER_RIGHT, [_key(KEY_RIGHT), _key(KEY_D), _joy_button(JOY_BUTTON_DPAD_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(FIRE, [_key(KEY_SPACE), _key(KEY_CTRL), _joy_button(JOY_BUTTON_A)])
	_add(FIRE_FRONT, [_key(KEY_UP), _key(KEY_W), _joy_button(JOY_BUTTON_DPAD_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add(FIRE_REAR, [_key(KEY_DOWN), _key(KEY_S), _joy_button(JOY_BUTTON_DPAD_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add(HISTORY_VIEW, [_key(KEY_TAB), _joy_button(JOY_BUTTON_Y)])
	_add(SIM_SPEED, [_key(KEY_F), _joy_button(JOY_BUTTON_X)])
	_add(BACK, [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_B)])
	_add(TOGGLE_PANEL, [_key(KEY_H), _joy_button(JOY_BUTTON_BACK)])
	_add(TOGGLE_LIGHTING, [_key(KEY_L)])
	_add(TOGGLE_STYLE, [_key(KEY_C), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)])


## Digital steering like a joystick: -1, 0 or +1. prefix selects a player's
## own actions ("" = the default single-player actions).
static func steer(prefix: String = "") -> float:
	var left := Input.is_action_pressed(prefix + STEER_LEFT)
	var right := Input.is_action_pressed(prefix + STEER_RIGHT)
	return float(int(right) - int(left))


static func fire_held(prefix: String = "") -> bool:
	return Input.is_action_pressed(prefix + FIRE)


static func _add(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, STICK_DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


## device: the joypad the event belongs to (0 = the single-player default, as before).
static func _joy_button(button: JoyButton, device: int = 0) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	return e


static func _joy_axis(axis: JoyAxis, value: float, device: int = 0) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = device
	return e
