class_name RaceSession
extends RefCounted
## Race flow for Milestone 1: choose control mode -> race -> finished.
## Elapsed time is a calibration aid for comparing against the original, not a
## claimed Super Cars II feature.

enum State { MODE_SELECT, RACING, FINISHED }

var state: State = State.MODE_SELECT
var control_mode: CarModel.ControlMode = CarModel.ControlMode.FIRE_TO_ACCELERATE
var tracker: LapTracker
var elapsed := 0.0
var lap_times: Array[float] = []
var _checkpoint_count: int
var _lap_count: int
var _lap_start := 0.0


func _init(checkpoint_count: int, lap_count: int) -> void:
	_checkpoint_count = checkpoint_count
	_lap_count = lap_count
	reset()


func reset() -> void:
	state = State.MODE_SELECT
	tracker = LapTracker.new(_checkpoint_count, _lap_count)
	elapsed = 0.0
	_lap_start = 0.0
	lap_times.clear()


func toggle_mode() -> void:
	if state != State.MODE_SELECT:
		return
	control_mode = CarModel.ControlMode.FIRE_TO_BRAKE if control_mode == CarModel.ControlMode.FIRE_TO_ACCELERATE else CarModel.ControlMode.FIRE_TO_ACCELERATE


func start() -> void:
	if state == State.MODE_SELECT:
		state = State.RACING


func tick(delta: float) -> void:
	if state == State.RACING:
		elapsed += delta


func checkpoint_reached(index: int) -> LapTracker.Result:
	if state != State.RACING:
		return LapTracker.Result.IGNORED
	var result := tracker.reach(index)
	if result == LapTracker.Result.LAP or result == LapTracker.Result.FINISHED:
		lap_times.append(elapsed - _lap_start)
		_lap_start = elapsed
	if result == LapTracker.Result.FINISHED:
		state = State.FINISHED
	return result
