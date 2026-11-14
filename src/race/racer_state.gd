class_name RacerState
extends RefCounted
## One car's race status: laps (from checkpoints), distance progress (for live
## positions), lap times and finish.

var id: int
var display_name: String
var is_player: bool
var tracker: LapTracker
var lap_times: Array[float] = []
## Distance driven along the centreline since the start/finish line, unwrapped
## across laps (negative while still behind the line on the grid).
var progress := 0.0
var finish_time := -1.0
## 1-based finishing position, 0 while still racing.
var finish_position := 0
var lap_start := 0.0


func _init(p_id: int, p_name: String, p_is_player: bool, checkpoint_count: int, lap_count: int) -> void:
	id = p_id
	display_name = p_name
	is_player = p_is_player
	tracker = LapTracker.new(checkpoint_count, lap_count)


func is_finished() -> bool:
	return finish_position > 0
