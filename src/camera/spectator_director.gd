class_name SpectatorDirector
extends RefCounted
## Chooses which car the spectator camera follows: the chasing car of the
## closest battle still racing, held for a minimum time to avoid jumpy cuts.
## Presentation only; it never affects the race.

## Minimum time on one car before cutting to another (s).
var min_hold := 4.0
var target_id := -1
var _held := 0.0


## cars: Array of {id, progress, finished}. Returns the id to follow.
func update(cars: Array, delta: float) -> int:
	_held += delta
	var current_running := false
	for c in cars:
		if c.id == target_id and not c.finished:
			current_running = true
	if target_id >= 0 and current_running and _held < min_hold:
		return target_id
	var best := choose(cars)
	if best >= 0 and best != target_id:
		target_id = best
		_held = 0.0
	return target_id


## The car behind in the closest gap between two running cars; the leader if
## only one is running; -1 if none.
static func choose(cars: Array) -> int:
	var running := cars.filter(func(c: Dictionary) -> bool: return not c.finished)
	if running.is_empty():
		return -1
	running.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.progress > b.progress)
	if running.size() == 1:
		return running[0].id
	var best_gap := INF
	var best_id: int = running[0].id
	for i in range(1, running.size()):
		var gap: float = running[i - 1].progress - running[i].progress
		if gap < best_gap:
			best_gap = gap
			best_id = running[i].id
	return best_id
