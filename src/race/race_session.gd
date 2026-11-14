class_name RaceSession
extends RefCounted
## Race flow: choose control mode -> race -> finished (when the player finishes).
## Holds every racer's laps, live positions and the finishing order.
## Racer 0 is the player; the single-racer API (tracker, lap_times,
## checkpoint_reached(index)) refers to the player.
## Elapsed time and lap times are calibration aids, not claimed original features.

enum State { MODE_SELECT, RACING, FINISHED }

const PLAYER_ID := 0

var state: State = State.MODE_SELECT
var control_mode: CarModel.ControlMode = CarModel.ControlMode.FIRE_TO_ACCELERATE
var racers: Array[RacerState] = []
var elapsed := 0.0
var finish_order: Array[int] = []
var _checkpoint_count: int
var _lap_count: int
var _names: PackedStringArray

## The player's lap tracker.
var tracker: LapTracker:
	get:
		return racers[PLAYER_ID].tracker
## The player's lap times.
var lap_times: Array[float]:
	get:
		return racers[PLAYER_ID].lap_times


## names[0] is the player; one racer is created per name.
func _init(checkpoint_count: int, lap_count: int, names: PackedStringArray = PackedStringArray(["YOU"])) -> void:
	_checkpoint_count = checkpoint_count
	_lap_count = lap_count
	_names = names
	reset()


func reset() -> void:
	state = State.MODE_SELECT
	elapsed = 0.0
	finish_order.clear()
	racers.clear()
	for i in _names.size():
		racers.append(RacerState.new(i, _names[i], i == PLAYER_ID, _checkpoint_count, _lap_count))


func racer_count() -> int:
	return racers.size()


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


## Laps keep counting for every car until it finishes, also after the player finished.
func checkpoint_reached(index: int, racer_id: int = PLAYER_ID) -> LapTracker.Result:
	if state == State.MODE_SELECT:
		return LapTracker.Result.IGNORED
	var r := racers[racer_id]
	var result := r.tracker.reach(index)
	if result == LapTracker.Result.LAP or result == LapTracker.Result.FINISHED:
		r.lap_times.append(elapsed - r.lap_start)
		r.lap_start = elapsed
	if result == LapTracker.Result.FINISHED:
		finish_order.append(racer_id)
		r.finish_position = finish_order.size()
		r.finish_time = elapsed
		if racer_id == PLAYER_ID:
			state = State.FINISHED
	return result


func set_progress(racer_id: int, progress: float) -> void:
	racers[racer_id].progress = progress


## Live order: finished cars by finishing order, then the rest by distance covered.
func standings() -> Array[RacerState]:
	var order: Array[RacerState] = racers.duplicate()
	order.sort_custom(func(a: RacerState, b: RacerState) -> bool:
		if a.is_finished() != b.is_finished():
			return a.is_finished()
		if a.is_finished():
			return a.finish_position < b.finish_position
		if a.tracker.laps_completed != b.tracker.laps_completed:
			return a.tracker.laps_completed > b.tracker.laps_completed
		if a.progress != b.progress:
			return a.progress > b.progress
		return a.id < b.id)
	return order


## 1-based live position of a racer.
func position_of(racer_id: int) -> int:
	var order := standings()
	for i in order.size():
		if order[i].id == racer_id:
			return i + 1
	return 0


## Next race's grid (slot 0 = pole) from this race's result, reversed:
## the winner starts last (Super Cars II manual, as reported; see backlog).
func reversed_grid() -> Array[int]:
	var ids: Array[int] = []
	for r in standings():
		ids.append(r.id)
	ids.reverse()
	return ids
