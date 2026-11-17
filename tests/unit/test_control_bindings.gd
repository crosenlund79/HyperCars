extends GutTest
## Remappable controls: assign, clashes refused (Fire never becomes Confirm),
## reserved Enter / Esc, save / load, restore defaults, couch copies.

const PATH := "user://test_controls.cfg"


func before_each() -> void:
	ControlBindings.path = PATH
	ControlBindings.restore_defaults()


func after_each() -> void:
	ControlBindings.restore_defaults()
	ControlBindings.path = ControlBindings.PATH
	for n in [1, 2]:
		for a in PlayerControls.PLAYER_ACTIONS:
			if InputMap.has_action(PlayerControls.player_prefix(n) + a):
				InputMap.erase_action(PlayerControls.player_prefix(n) + a)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _pad(button: JoyButton, device := 3) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = device
	e.pressed = true
	return e


func test_defaults_are_listed() -> void:
	assert_string_contains(ControlBindings.describe(PlayerControls.FIRE, ControlBindings.KEYBOARD), "Space")
	assert_string_contains(ControlBindings.describe(PlayerControls.FIRE, ControlBindings.PAD), "Pad A")
	assert_string_contains(ControlBindings.describe(PlayerControls.CONFIRM, ControlBindings.KEYBOARD), "Enter")


func test_assign_replaces_that_kind_only() -> void:
	assert_eq(ControlBindings.assign(PlayerControls.FIRE, _key(KEY_J)), "")
	assert_eq(ControlBindings.describe(PlayerControls.FIRE, ControlBindings.KEYBOARD), "J")
	assert_true(InputMap.event_is_action(_key(KEY_J), PlayerControls.FIRE))
	assert_false(InputMap.event_is_action(_key(KEY_SPACE), PlayerControls.FIRE))
	assert_true(InputMap.event_is_action(_pad(JOY_BUTTON_A, 0), PlayerControls.FIRE), "pad binding kept")
	assert_eq(ControlBindings.assign(PlayerControls.FIRE, _pad(JOY_BUTTON_RIGHT_SHOULDER)), "")
	assert_eq(ControlBindings.events(PlayerControls.FIRE, ControlBindings.PAD).size(), 1)
	assert_eq(ControlBindings.events(PlayerControls.FIRE, ControlBindings.PAD)[0].device, 0, "stored device-independent")


func test_clashes_are_refused_and_fire_never_confirms() -> void:
	var err := ControlBindings.assign(PlayerControls.CONFIRM, _key(KEY_SPACE))
	assert_string_contains(err, "already used for Fire")
	assert_false(InputMap.event_is_action(_key(KEY_SPACE), PlayerControls.CONFIRM))
	assert_ne(ControlBindings.assign(PlayerControls.CONFIRM, _pad(JOY_BUTTON_A)), "", "pad Fire cannot confirm either")
	assert_string_contains(ControlBindings.assign(PlayerControls.FIRE, _key(KEY_ENTER)), "reserved for Confirm")
	assert_string_contains(ControlBindings.assign(PlayerControls.STEER_LEFT, _key(KEY_ESCAPE)), "reserved for Back")


func test_confirm_and_back_keep_enter_and_escape() -> void:
	assert_eq(ControlBindings.assign(PlayerControls.CONFIRM, _key(KEY_Y)), "")
	assert_true(InputMap.event_is_action(_key(KEY_Y), PlayerControls.CONFIRM))
	assert_true(InputMap.event_is_action(_key(KEY_ENTER), PlayerControls.CONFIRM), "Enter always confirms")
	assert_eq(ControlBindings.assign(PlayerControls.BACK, _key(KEY_Q)), "")
	assert_true(InputMap.event_is_action(_key(KEY_ESCAPE), PlayerControls.BACK), "Esc always goes back")


func test_saved_bindings_load_and_defaults_restore() -> void:
	ControlBindings.assign(PlayerControls.FIRE, _key(KEY_J))
	ControlBindings.assign(PlayerControls.STEER_LEFT, _pad(JOY_BUTTON_LEFT_SHOULDER))
	ControlBindings.save()
	ControlBindings.restore_defaults()  # also deletes the file...
	assert_true(InputMap.event_is_action(_key(KEY_SPACE), PlayerControls.FIRE), "defaults back")
	ControlBindings.assign(PlayerControls.FIRE, _key(KEY_J))
	ControlBindings.assign(PlayerControls.STEER_LEFT, _pad(JOY_BUTTON_LEFT_SHOULDER))
	ControlBindings.save()
	for a in ControlBindings.ACTIONS:  # ...so simulate a fresh start
		InputMap.erase_action(a[0])
	ControlBindings.load_saved()
	assert_true(InputMap.event_is_action(_key(KEY_J), PlayerControls.FIRE))
	assert_false(InputMap.event_is_action(_key(KEY_SPACE), PlayerControls.FIRE))
	assert_true(InputMap.event_is_action(_pad(JOY_BUTTON_LEFT_SHOULDER, 0), PlayerControls.STEER_LEFT))
	assert_true(InputMap.event_is_action(_key(KEY_ENTER), PlayerControls.CONFIRM))


func test_couch_players_copy_the_remapped_bindings_on_their_own_device() -> void:
	ControlBindings.assign(PlayerControls.FIRE, _pad(JOY_BUTTON_RIGHT_SHOULDER))
	ControlBindings.assign(PlayerControls.FIRE, _key(KEY_J))
	var p1 := PlayerControls.ensure_player_actions(1, PlayerControls.KEYBOARD)
	var p2 := PlayerControls.ensure_player_actions(2, 3)
	assert_true(InputMap.event_is_action(_key(KEY_J), p1 + PlayerControls.FIRE))
	assert_false(InputMap.event_is_action(_pad(JOY_BUTTON_RIGHT_SHOULDER, 3), p1 + PlayerControls.FIRE))
	assert_true(InputMap.event_is_action(_pad(JOY_BUTTON_RIGHT_SHOULDER, 3), p2 + PlayerControls.FIRE))
	assert_false(InputMap.event_is_action(_pad(JOY_BUTTON_RIGHT_SHOULDER, 1), p2 + PlayerControls.FIRE), "only its own pad")
	assert_false(InputMap.event_is_action(_key(KEY_J), p2 + PlayerControls.FIRE))


func test_controls_screen_remaps_with_a_key_press() -> void:
	var panel := ControlsPanel.new()
	add_child_autofree(panel)
	panel.setup()
	panel._listen(PlayerControls.FIRE_FRONT, ControlBindings.KEYBOARD)
	panel._input(_key(KEY_I))
	assert_eq(ControlBindings.describe(PlayerControls.FIRE_FRONT, ControlBindings.KEYBOARD), "I")
	assert_eq(panel._slots[[PlayerControls.FIRE_FRONT, ControlBindings.KEYBOARD]].text, "I")
	panel._listen(PlayerControls.FIRE_REAR, ControlBindings.KEYBOARD)
	panel._input(_key(KEY_I))
	assert_string_contains(panel._status.text, "already used for Front weapon")
	panel._listen(PlayerControls.FIRE_REAR, ControlBindings.KEYBOARD)
	panel._input(_key(KEY_ESCAPE))
	assert_true(panel.waiting.is_empty(), "Esc cancels")
	assert_string_contains(ControlBindings.describe(PlayerControls.FIRE_REAR, ControlBindings.KEYBOARD), "Down")
	panel.restore_defaults()
	assert_string_contains(ControlBindings.describe(PlayerControls.FIRE_FRONT, ControlBindings.KEYBOARD), "Up")
