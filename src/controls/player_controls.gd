class_name PlayerControls
extends RefCounted
## Joystick-style controls for one player: left/right steer, one fire button.
## Joystick up/down are weapon inputs in the original and are deliberately unbound
## (no weapons in Milestone 1). Actions are only created if the project does not
## already define them, so they can be rebound in Project Settings > Input Map.

const STEER_LEFT := "steer_left"
const STEER_RIGHT := "steer_right"
const FIRE := "fire"
## Spectator mode only: switch history view, toggle simulation speed, leave.
const HISTORY_VIEW := "history_view"
const SIM_SPEED := "sim_speed"
const BACK := "back"
const STICK_DEADZONE := 0.5


static func ensure_actions() -> void:
	_add(STEER_LEFT, [_key(KEY_LEFT), _key(KEY_A), _joy_button(JOY_BUTTON_DPAD_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(STEER_RIGHT, [_key(KEY_RIGHT), _key(KEY_D), _joy_button(JOY_BUTTON_DPAD_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(FIRE, [_key(KEY_SPACE), _key(KEY_CTRL), _joy_button(JOY_BUTTON_A)])
	_add(HISTORY_VIEW, [_key(KEY_TAB), _joy_button(JOY_BUTTON_Y)])
	_add(SIM_SPEED, [_key(KEY_F), _joy_button(JOY_BUTTON_X)])
	_add(BACK, [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_B)])


## Digital steering like a joystick: -1, 0 or +1.
static func steer() -> float:
	var left := Input.is_action_pressed(STEER_LEFT)
	var right := Input.is_action_pressed(STEER_RIGHT)
	return float(int(right) - int(left))


static func fire_held() -> bool:
	return Input.is_action_pressed(FIRE)


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


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
