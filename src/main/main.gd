extends Node2D
## Composition root: one circuit, the player car plus computer opponents, camera
## and HUD. Owns the asset resolver and wires modules together through explicit
## calls/signals. Racer id == index in cars; 0 is the player.

const CAR_SCENE := preload("res://src/driving/car.tscn")
const MAX_OPPONENTS := 9

@export var driving_params: DrivingParams = preload("res://src/driving/default_driving_params.tres")
@export var ai_params: AiParams = preload("res://src/ai/default_ai_params.tres")
## Computer opponents (0-9). The original field is 10 cars: the player + 9.
@export_range(0, MAX_OPPONENTS) var opponent_count := MAX_OPPONENTS
## Player's grid slot in the first race (0 = pole, -1 = back of the grid). PROVISIONAL:
## the original's first-race grid order is unverified; later races use the reversed result.
@export var player_first_grid_slot := -1

var resolver: AssetResolver
var session: RaceSession
var racing_line: RacingLine
var cars: Array[Car] = []
var drivers: Array[AiDriver] = []
var progress: Array[RaceProgress] = []
## grid_order[slot] = racer id.
var grid_order: Array[int] = []

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
	for i in opponent_count:
		names.append("CPU %d" % (i + 1))
	session = RaceSession.new(track.checkpoint_count(), track.layout.lap_count, names)
	hud.setup(resolver)
	camera.target = car
	racing_line = RacingLine.new(track.path, track.layout.road_width, driving_params, ai_params)

	car.racer_id = RaceSession.PLAYER_ID
	car.setup(driving_params, session.control_mode, resolver.get_texture(AssetCatalog.CAR_PLAYER))
	cars.append(car)
	drivers.append(null)
	for i in range(1, opponent_count + 1):
		var ai_car: Car = CAR_SCENE.instantiate()
		ai_car.name = "AiCar%d" % i
		ai_car.racer_id = i
		add_child(ai_car)
		move_child(ai_car, car.get_index())
		ai_car.setup(driving_params, CarModel.ControlMode.FIRE_TO_ACCELERATE, resolver.get_texture(AssetCatalog.ai_car(i)))
		cars.append(ai_car)
		drivers.append(AiDriver.new(racing_line, ai_params))
	for c in cars:
		progress.append(RaceProgress.new(track.path))
	grid_order = first_grid(cars.size(), player_first_grid_slot)
	reset_race()


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


func reset_race() -> void:
	session.reset()
	for slot in grid_order.size():
		var id := grid_order[slot]
		var c := cars[id]
		c.active = false
		c.place(track.grid_transform(slot))
		progress[id].reset(c.global_position)
		session.set_progress(id, progress[id].distance)
		if drivers[id] != null:
			drivers[id].lane_bias = 0.0
	camera.snap_to_target()
	_update_hud()
	hud.show_mode_select(session.control_mode)


func _physics_process(delta: float) -> void:
	match session.state:
		RaceSession.State.MODE_SELECT:
			if Input.is_action_just_pressed(PlayerControls.STEER_LEFT) or Input.is_action_just_pressed(PlayerControls.STEER_RIGHT):
				session.toggle_mode()
				hud.show_mode_select(session.control_mode)
			elif Input.is_action_just_pressed(PlayerControls.FIRE):
				_start_race()
			return
		RaceSession.State.RACING:
			car.steer = PlayerControls.steer()
			car.fire = PlayerControls.fire_held()
		RaceSession.State.FINISHED:
			# After the flag the player has no control; the car brakes to a stop.
			car.steer = 0.0
			car.fire = car.model.control_mode == CarModel.ControlMode.FIRE_TO_BRAKE
			if Input.is_action_just_pressed(PlayerControls.FIRE):
				grid_order = session.reversed_grid()
				reset_race()
				return
	_update_progress()
	_drive_opponents(delta)
	session.tick(delta)
	_update_hud()
	if session.state == RaceSession.State.FINISHED:
		hud.show_results(session.standings())


func _start_race() -> void:
	car.model.control_mode = session.control_mode
	for c in cars:
		c.active = true
	session.start()
	hud.show_racing(session.control_mode)


func _update_progress() -> void:
	for id in cars.size():
		progress[id].update(cars[id].global_position)
		session.set_progress(id, progress[id].distance)


func _drive_opponents(delta: float) -> void:
	for id in range(1, cars.size()):
		var others: Array = []
		for other in cars.size():
			if other != id:
				others.append({"distance": progress[other].distance, "lateral": progress[other].lateral,
					"speed": cars[other].model.forward_speed()})
		var me := {"position": cars[id].global_position, "heading": cars[id].model.heading,
			"speed": cars[id].model.forward_speed(), "distance": progress[id].distance,
			"lateral": progress[id].lateral}
		var out := drivers[id].decide(me, others, delta)
		cars[id].steer = out.steer
		cars[id].fire = out.fire


func _update_hud() -> void:
	var p := session.racers[RaceSession.PLAYER_ID]
	hud.update_race(p.tracker.current_lap(), p.tracker.lap_count, session.elapsed,
		session.position_of(RaceSession.PLAYER_ID), session.racer_count())


func _on_checkpoint_reached(index: int, body: Node2D) -> void:
	var c := body as Car
	if c == null or not c.active:
		return
	session.checkpoint_reached(index, c.racer_id)
