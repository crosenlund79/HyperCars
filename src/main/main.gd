extends Node2D
## Milestone 1 composition root: one circuit, one player car, camera and HUD.
## Owns the asset resolver and wires modules together through explicit calls/signals.

@export var driving_params: DrivingParams = preload("res://src/driving/default_driving_params.tres")

var resolver: AssetResolver
var session: RaceSession

@onready var track: Track = $Track
@onready var car: Car = $Car
@onready var camera: FollowCamera = $FollowCamera
@onready var hud: Hud = $Hud


func _ready() -> void:
	PlayerControls.ensure_actions()
	resolver = AssetResolver.new()
	track.build(resolver)
	track.checkpoint_reached.connect(_on_checkpoint_reached)
	session = RaceSession.new(track.checkpoint_count(), track.layout.lap_count)
	hud.setup(resolver)
	camera.target = car
	car.setup(driving_params, session.control_mode, resolver.get_texture(AssetCatalog.CAR_PLAYER))
	reset_race()


func reset_race() -> void:
	session.reset()
	car.active = false
	car.place(track.start_transform())
	camera.snap_to_target()
	hud.update_race(session.tracker.current_lap(), session.tracker.lap_count, 0.0)
	hud.show_mode_select(session.control_mode)


func _physics_process(delta: float) -> void:
	match session.state:
		RaceSession.State.MODE_SELECT:
			if Input.is_action_just_pressed(PlayerControls.STEER_LEFT) or Input.is_action_just_pressed(PlayerControls.STEER_RIGHT):
				session.toggle_mode()
				hud.show_mode_select(session.control_mode)
			elif Input.is_action_just_pressed(PlayerControls.FIRE):
				_start_race()
		RaceSession.State.RACING:
			car.steer = PlayerControls.steer()
			car.fire = PlayerControls.fire_held()
			session.tick(delta)
			hud.update_race(session.tracker.current_lap(), session.tracker.lap_count, session.elapsed)
		RaceSession.State.FINISHED:
			# After the flag the player has no control; the car brakes to a stop.
			car.steer = 0.0
			car.fire = car.model.control_mode == CarModel.ControlMode.FIRE_TO_BRAKE
			if Input.is_action_just_pressed(PlayerControls.FIRE):
				reset_race()


func _start_race() -> void:
	car.model.control_mode = session.control_mode
	car.active = true
	session.start()
	hud.show_racing(session.control_mode)


func _on_checkpoint_reached(index: int, body: Node2D) -> void:
	if body != car:
		return
	var result := session.checkpoint_reached(index)
	if result == LapTracker.Result.FINISHED:
		hud.show_finished(session.lap_times, session.elapsed)
