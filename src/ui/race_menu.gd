class_name RaceMenu
extends CanvasLayer
## The in-race Esc menu: RESUME RACE / LEAVE RACE. Keeps working while the game
## is paused (process mode Always). The race scene decides what pausing means
## (single-player, spectator and couch pause; a network race goes on).

signal resume_requested
signal leave_requested

var _panel: PanelContainer
var _title: Label
var _note: Label
var _resume: Button
var _leave: Button
var _opened_frame := -1


func setup(theme: Theme) -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.theme = theme
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_title = HyperTheme.label("RACE PAUSED", 34, HyperTheme.GOLD, 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_note = HyperTheme.label("", 17, HyperTheme.CREAM_DIM, 500)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	_resume = _button("RESUME RACE", func() -> void: resume_requested.emit())
	_leave = _button("LEAVE RACE", func() -> void: leave_requested.emit())
	box.add_child(_resume)
	box.add_child(_leave)
	var hint := HyperTheme.label("Up / Down: choose    Enter / Space / A: select    Esc: resume", 15, HyperTheme.CREAM_DIM, 500)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	visible = false


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 46)
	b.pressed.connect(action)
	b.mouse_entered.connect(b.grab_focus)
	return b


## network: the race goes on for the other player while the menu is open.
func open(network: bool) -> void:
	_title.text = "RACE MENU" if network else "RACE PAUSED"
	_note.text = "The race goes on for the other player: your car brakes." if network else "The race is paused."
	visible = true
	_panel.reset_size()
	_panel.position = (Vector2(1280, 720) - _panel.get_combined_minimum_size()) * 0.5
	_resume.grab_focus()
	_opened_frame = Engine.get_process_frames()


## The leave button's label (a championship round abandons the championship).
func set_leave_text(text: String) -> void:
	_leave.text = text


func close() -> void:
	visible = false
	for b in [_resume, _leave]:
		if b.has_focus():
			b.release_focus()


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	# Esc (any player's Back) resumes; not in the frame that opened the menu
	if visible and Engine.get_process_frames() != _opened_frame and _back_pressed():
		resume_requested.emit()


static func _back_pressed() -> bool:
	for action in [PlayerControls.BACK, "p1_" + PlayerControls.BACK, "p2_" + PlayerControls.BACK]:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false
