extends Node
## Game root (run/main_scene): owns the title screen and starts the race scene
## (src/main/main.tscn) as a child with the chosen mode, fading between them.
## Loads and applies the saved audio settings. The race scene itself is
## unchanged and still runs on its own (tests use it directly).
## Garage races (M3.5): one PlayerGarage lives for the whole game session (money
## and weapons carry over between garage races until the game quits); the
## garage screen opens before the first garage race and after each one.

const MAIN_SCENE := preload("res://src/main/main.tscn")

## Where achievements and rival careers are saved (tests use a scratch file).
@export var achievements_path := AchievementStore.DEFAULT_PATH

var resolver: AssetResolver
var settings: AudioSettings
var title: TitleScreen
var race: Node2D
var _fade: ColorRect
var garage: PlayerGarage
var garage_screen: GarageScreen
## Achievements (M3.5): one persistent store for the installation, the toast.
var achievements: AchievementStore
var toast: AchievementToast


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	settings = AudioSettings.new()
	settings.load_settings()
	settings.apply()
	resolver = AssetResolver.new()
	achievements = AchievementStore.new(achievements_path)
	achievements.load_store()
	toast = AchievementToast.new()
	toast.name = "AchievementToast"
	add_child(toast)
	toast.setup(resolver)
	achievements.unlocked.connect(toast.show_unlock)
	title = TitleScreen.new()
	title.name = "Title"
	title.achievements = achievements
	add_child(title)
	title.setup(resolver, settings)
	title.start_requested.connect(start_race)
	title.two_player_requested.connect(func(devices: Array[int]) -> void: start_race(0, false, devices))
	title.quit_requested.connect(quit_game)
	garage = PlayerGarage.new(load("res://src/garage/default_garage_rules.tres"))
	garage_screen = GarageScreen.new()
	garage_screen.name = "Garage"
	add_child(garage_screen)
	garage_screen.setup(garage, resolver)
	garage_screen.race_requested.connect(func() -> void: _close_garage(true))
	garage_screen.closed.connect(func() -> void: _close_garage(false))
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
## with_garage: a garage race (money and the player's own weapons).
## devices: two-player split-screen with these controllers (no garage or
## achievements in two-player races).
func start_race(choice: int, with_garage: bool = false, devices: Array[int] = []) -> void:
	await _fade_to(1.0)
	title.hide_title()
	race = MAIN_SCENE.instantiate()
	race.allow_exit = true
	var two := devices.size() == 2
	if two:
		race.human_count = 2
		race.player_devices = devices
	elif with_garage and choice != 2:
		race.garage = garage
	if not two:
		race.achievements = achievements
	race.track_variant = title.track_variant
	add_child(race)
	race.garage_requested.connect(_open_garage)
	race.camera.make_current()
	race.set_menu_choice(choice)
	race.set_weapons_enabled(title.weapons_on)
	race.set_combat_style(title.combat_style)
	race.set_lap_count(title.laps)
	race.exit_requested.connect(back_to_title)
	if choice == 2:
		race.start_race()  # spectating starts straight away
	elif with_garage:
		race.open_garage()  # shop before the first garage race
	await _fade_to(0.0)


func _open_garage() -> void:
	garage_screen.open()


func _close_garage(start: bool) -> void:
	garage_screen.close()
	if race != null:
		race.close_garage(start)


func back_to_title() -> void:
	await _fade_to(1.0)
	garage_screen.close()
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
