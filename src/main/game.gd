extends Node
## Game root (run/main_scene): owns the title screen and starts the race scene
## (src/main/main.tscn) as a child with the chosen mode, fading between them.
## Loads and applies the saved audio settings. The race scene itself is
## unchanged and still runs on its own (tests use it directly).

const MAIN_SCENE := preload("res://src/main/main.tscn")

var resolver: AssetResolver
var settings: AudioSettings
var title: TitleScreen
var race: Node2D
var _fade: ColorRect


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	settings = AudioSettings.new()
	settings.load_settings()
	settings.apply()
	resolver = AssetResolver.new()
	title = TitleScreen.new()
	title.name = "Title"
	add_child(title)
	title.setup(resolver, settings)
	title.start_requested.connect(start_race)
	title.quit_requested.connect(quit_game)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("1c1614")
	_fade.size = Vector2(1280, 720)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	await _fade_to(0.0)


## choice: 0 Fire to Accelerate, 1 Fire to Brake, 2 Spectate rivals.
func start_race(choice: int) -> void:
	await _fade_to(1.0)
	title.hide_title()
	race = MAIN_SCENE.instantiate()
	race.allow_exit = true
	add_child(race)
	race.camera.make_current()
	race.set_menu_choice(choice)
	race.exit_requested.connect(back_to_title)
	if choice == 2:
		race.start_race()  # spectating starts straight away
	await _fade_to(0.0)


func back_to_title() -> void:
	await _fade_to(1.0)
	if race != null:
		race.queue_free()
		race = null
	title.show_title()
	await _fade_to(0.0)


func quit_game() -> void:
	await _fade_to(1.0)
	_shutdown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()


## Stops audio a few frames before quitting so no stream playback outlives the
## scene (Godot otherwise reports it at exit).
func _shutdown() -> void:
	title.stop_audio()
	if race != null:
		race.queue_free()
		race = null
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()


func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, 0.25)
	await tw.finished
	_fade.visible = alpha > 0.0
