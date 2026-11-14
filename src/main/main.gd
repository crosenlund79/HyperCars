extends Node2D
## Composition root: one circuit, the player car plus the nine recurring rivals,
## camera and HUD. Owns the asset resolver and wires modules together through
## explicit calls/signals. Racer id == index in cars; 0 is the player, 1..9 are
## the rivals of RivalRoster.
## Modes (chosen on the menu): a race with the player in either control mode, or
## spectating the nine rivals race back to back, at normal or fast simulation.

enum Choice { FIRE_TO_ACCELERATE, FIRE_TO_BRAKE, SPECTATE }

const CAR_SCENE := preload("res://src/driving/car.tscn")
const MAX_OPPONENTS := 9
const BASE_TICKS := 60
## Spectator: simulated seconds the result stays up before the next race starts.
const RESTART_DELAY := 3.0
## Spectator safety net: if cars are still running this long after the winner
## finished, they are classified in running order (prevents an endless race).
const CLASSIFY_AFTER_WINNER := 120.0

@export var driving_params: DrivingParams = preload("res://src/driving/default_driving_params.tres")
@export var ai_params: AiParams = preload("res://src/ai/default_ai_params.tres")
## Computer opponents (0-9). The original field is 10 cars: the player + 9.
@export_range(0, MAX_OPPONENTS) var opponent_count := MAX_OPPONENTS
## Player's grid slot in the first race (0 = pole, -1 = back of the grid). PROVISIONAL:
## the original's first-race grid order is unverified; later races use the reversed result.
@export var player_first_grid_slot := -1
## Base seed for the rivals' decision randomness. Same seed + same race number
## = same decisions (used to compare normal and fast simulation).
@export var base_seed := 1991
## Simulation multiplier used by the spectator "fast" option.
@export_range(2, 16) var fast_multiplier := 4

var resolver: AssetResolver
var session: RaceSession
var racing_line: RacingLine
var cars: Array[Car] = []
var drivers: Array[AiDriver] = []
var progress: Array[RaceProgress] = []
## grid_order[slot] = racer id, for the current mode.
var grid_order: Array[int] = []
var menu_choice: Choice = Choice.FIRE_TO_ACCELERATE
## Races started so far (seeds the rivals' decisions).
var races_started := 0
var history: RaceHistory
var director := SpectatorDirector.new()
var sim_speed := 1
var _race_grid: Array[int] = []
var _spectator_grid: Array[int] = []
var _restart_timer := -1.0
var _winner_time := -1.0

@onready var track: Track = $Track
@onready var car: Car = $Car
@onready var camera: FollowCamera = $FollowCamera
@onready var hud: Hud = $Hud


func _ready() -> void:
	PlayerControls.ensure_actions()
	resolver = AssetResolver.new()
	track.build(resolver)
	track.checkpoint_reached.connect(_on_checkpoint_reached)
	var names := PackedStringArray(["YOU"])
	for i in range(1, opponent_count + 1):
		names.append(RivalRoster.short_name(i))
	session = RaceSession.new(track.checkpoint_count(), track.layout.lap_count, names)
	hud.setup(resolver)
	camera.target = car
	racing_line = RacingLine.new(track.path, track.layout.road_width, driving_params, ai_params)

	car.racer_id = RaceSession.PLAYER_ID
	car.setup(driving_params, session.control_mode, resolver.get_texture(AssetCatalog.CAR_PLAYER))
	cars.append(car)
	drivers.append(null)
	var rival_ids: Array[int] = []
	var car_textures := {}
	var full_names := {}
	for i in range(1, opponent_count + 1):
		var ai_car: Car = CAR_SCENE.instantiate()
		ai_car.name = "AiCar%d" % i
		ai_car.racer_id = i
		add_child(ai_car)
		move_child(ai_car, car.get_index())
		var texture := resolver.get_texture(AssetCatalog.ai_car(i))
		ai_car.setup(driving_params, CarModel.ControlMode.FIRE_TO_ACCELERATE, texture)
		cars.append(ai_car)
		var params: AiParams = load(RivalRoster.params_path(i)) if RivalRoster.has_personality(i) else ai_params
		drivers.append(AiDriver.new(racing_line, params))
		rival_ids.append(i)
		car_textures[i] = texture
		full_names[i] = RivalRoster.full_name(i)
	for c in cars:
		progress.append(RaceProgress.new(track.path))
	history = RaceHistory.new(rival_ids)
	hud.setup_history(resolver, history, car_textures, full_names)
	_race_grid = first_grid(cars.size(), player_first_grid_slot)
	_spectator_grid = rival_ids.duplicate()
	grid_order = _race_grid
	reset_race()


func _exit_tree() -> void:
	set_sim_speed(1)


## Opponents fill the grid in id order around the player's slot.
static func first_grid(field_size: int, player_slot: int) -> Array[int]:
	var slot := field_size - 1 if player_slot < 0 else mini(player_slot, field_size - 1)
	var order: Array[int] = []
	var next_ai := 1
	for s in field_size:
		if s == slot:
			order.append(RaceSession.PLAYER_ID)
		else:
			order.append(next_ai)
			next_ai += 1
	return order


## Simulation throughput multiplier. Every physics tick still advances the race by
## exactly Car.FIXED_STEP with the same AI inputs and collision calculations; fast
## mode only runs more ticks per real second.
func set_sim_speed(multiplier: int) -> void:
	sim_speed = maxi(1, multiplier)
	Engine.physics_ticks_per_second = BASE_TICKS * sim_speed
	Engine.time_scale = sim_speed
	Engine.max_physics_steps_per_frame = maxi(8, sim_speed * 2)


func reset_race() -> void:
	session.reset()
	_restart_timer = -1.0
	_winner_time = -1.0
	_show_player_car(not session.spectator)
	for slot in grid_order.size():
		var id := grid_order[slot]
		var c := cars[id]
		c.active = false
		c.place(track.grid_transform(slot))
		progress[id].reset(c.global_position)
		session.set_progress(id, progress[id].distance)
	_update_camera_target()
	camera.snap_to_target()
	hud.history_panel.visible = session.spectator
	_refresh_hud()
	hud.show_menu(choice_name(menu_choice))


static func choice_name(choice: Choice) -> String:
	match choice:
		Choice.FIRE_TO_BRAKE: return "FIRE TO BRAKE"
		Choice.SPECTATE: return "SPECTATE RIVALS"
	return "FIRE TO ACCELERATE"


func set_menu_choice(choice: Choice) -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	menu_choice = choice
	var spectate := choice == Choice.SPECTATE
	if not spectate:
		session.control_mode = CarModel.ControlMode.FIRE_TO_BRAKE if choice == Choice.FIRE_TO_BRAKE else CarModel.ControlMode.FIRE_TO_ACCELERATE
	if spectate != session.spectator:
		session.set_spectator(spectate)
		grid_order = _spectator_grid if spectate else _race_grid
		reset_race()
	hud.show_menu(choice_name(menu_choice))


func _physics_process(_delta: float) -> void:
	var step := Car.FIXED_STEP
	match session.state:
		RaceSession.State.MODE_SELECT:
			if Input.is_action_just_pressed(PlayerControls.STEER_LEFT):
				set_menu_choice(posmod(menu_choice - 1, 3) as Choice)
			elif Input.is_action_just_pressed(PlayerControls.STEER_RIGHT):
				set_menu_choice(posmod(menu_choice + 1, 3) as Choice)
			elif Input.is_action_just_pressed(PlayerControls.FIRE):
				start_race()
			return
		RaceSession.State.RACING:
			if not session.spectator:
				car.steer = PlayerControls.steer()
				car.fire = PlayerControls.fire_held()
		RaceSession.State.FINISHED:
			if not session.spectator:
				# After the flag the player has no control; the car brakes to a stop.
				car.steer = 0.0
				car.fire = car.model.control_mode == CarModel.ControlMode.FIRE_TO_BRAKE
				if Input.is_action_just_pressed(PlayerControls.FIRE):
					_race_grid = session.reversed_grid()
					grid_order = _race_grid
					reset_race()
					return
	if session.spectator and _spectator_input():
		return
	_update_progress()
	_drive_opponents(step)
	session.tick(step)
	if session.spectator:
		_spectator_tick(step)
	_update_camera_target(step)


func start_race() -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	races_started += 1
	car.model.control_mode = session.control_mode
	for id in grid_order:
		cars[id].active = true
		if drivers[id] != null:
			drivers[id].begin_race(race_seed(races_started, id))
	session.start()
	hud.hide_message()


## Seed of a rival's decisions in a given race (stable across sessions).
func race_seed(race_number: int, racer_id: int) -> int:
	return hash([base_seed, race_number, racer_id])


func _spectator_input() -> bool:
	if Input.is_action_just_pressed(PlayerControls.BACK):
		set_sim_speed(1)
		session.state = RaceSession.State.MODE_SELECT
		grid_order = _spectator_grid
		reset_race()
		return true
	if Input.is_action_just_pressed(PlayerControls.SIM_SPEED):
		set_sim_speed(1 if sim_speed > 1 else fast_multiplier)
	if Input.is_action_just_pressed(PlayerControls.HISTORY_VIEW):
		hud.history_panel.toggle_view()
	if Input.is_action_just_pressed(PlayerControls.STEER_LEFT):
		hud.history_panel.scroll_columns(-3)
	if Input.is_action_just_pressed(PlayerControls.STEER_RIGHT):
		hud.history_panel.scroll_columns(3)
	return false


## Records each finished race, shows the result briefly, then starts the next
## race from the reversed grid.
func _spectator_tick(step: float) -> void:
	if session.state == RaceSession.State.RACING:
		if _winner_time < 0.0 and not session.finish_order.is_empty():
			_winner_time = session.elapsed
		if _winner_time >= 0.0 and session.elapsed - _winner_time > CLASSIFY_AFTER_WINNER:
			session.classify_remaining()
	if session.state == RaceSession.State.FINISHED:
		if _restart_timer < 0.0:
			history.add_race(session.finish_order)
			hud.history_panel.refresh()
			_restart_timer = RESTART_DELAY
			hud.show_results(session.standings(), "Next race starting...")
		_restart_timer -= step
		if _restart_timer <= 0.0:
			_spectator_grid = session.reversed_grid()
			grid_order = _spectator_grid
			reset_race()
			start_race()


func _show_player_car(on: bool) -> void:
	car.visible = on
	car.collision_layer = 2 if on else 0
	car.collision_mask = 3 if on else 0
	if not on:
		car.active = false
		car.place(Transform2D(0.0, Vector2(-100000, -100000)))


func _update_camera_target(step: float = 0.0) -> void:
	if not session.spectator:
		camera.target = car
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2.ONE
		return
	var view: Array = []
	for r in session.participants():
		view.append({"id": r.id, "progress": r.progress, "finished": r.is_finished()})
	var id := director.update(view, step)
	if id > 0:
		camera.target = cars[id]
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.zoom = Vector2(0.85, 0.85)


func _process(_delta: float) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if session.spectator:
		var leader := session.standings()[0] if session.racer_count() > 0 else null
		var following := RivalRoster.short_name(director.target_id) if director.target_id > 0 else "-"
		hud.update_spectator(history.race_count() + (0 if session.state == RaceSession.State.FINISHED else 1),
			leader.tracker.current_lap() if leader != null else 1, session.racers[0].tracker.lap_count,
			session.elapsed, "x%d" % sim_speed, following)
		return
	var p := session.racers[RaceSession.PLAYER_ID]
	var time := p.finish_time if p.is_finished() else session.elapsed
	hud.update_race(p.tracker.current_lap(), p.tracker.lap_count, time,
		session.position_of(RaceSession.PLAYER_ID), session.racer_count())
	if session.state == RaceSession.State.FINISHED:
		hud.show_results(session.standings())


func _update_progress() -> void:
	for id in grid_order:
		progress[id].update(cars[id].global_position)
		session.set_progress(id, progress[id].distance)


func _drive_opponents(step: float) -> void:
	for id in grid_order:
		if drivers[id] == null:
			continue
		var others: Array = []
		for other in grid_order:
			if other != id:
				others.append({"distance": progress[other].distance, "lateral": progress[other].lateral,
					"speed": cars[other].model.forward_speed()})
		var me := {"position": cars[id].global_position, "heading": cars[id].model.heading,
			"speed": cars[id].model.forward_speed(), "distance": progress[id].distance,
			"lateral": progress[id].lateral}
		var out := drivers[id].decide(me, others, step)
		cars[id].steer = out.steer
		cars[id].fire = out.fire


func _on_checkpoint_reached(index: int, body: Node2D) -> void:
	var c := body as Car
	if c == null or not c.active:
		return
	session.checkpoint_reached(index, c.racer_id)
