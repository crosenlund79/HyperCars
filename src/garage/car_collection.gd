class_name CarCollection
extends RefCounted
## Rival cars the player has won (Championship reward), kept between game
## sessions (user://car_collection.cfg). A won car belongs to the player: its
## original owner races a battered junker from then on. All cars perform the
## same; this is about ownership and looks only.

const DEFAULT_PATH := "user://car_collection.cfg"
## The player's own (original) car.
const OWN_CAR := 0

var path: String
## Rival racer ids (1..9) whose cars the player owns, in the order won.
var owned: Array[int] = []
## Championships started so far (the next one's schedule rotates with it).
var championships_run := 0


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	load_from_disk()


func load_from_disk() -> void:
	owned.clear()
	championships_run = 0
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	championships_run = maxi(0, int(cfg.get_value("cars", "championships_run", 0)))
	for id in cfg.get_value("cars", "owned", []):
		if int(id) >= 1 and int(id) <= 9 and not owned.has(int(id)):
			owned.append(int(id))


func save() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("cars", "owned", owned)
	cfg.set_value("cars", "championships_run", championships_run)
	return cfg.save(path)


func owns(rival_id: int) -> bool:
	return owned.has(rival_id)


## A rival now drives the junker (the player won their car).
func displaced(rival_id: int) -> bool:
	return owned.has(rival_id)


func all_owned() -> bool:
	return owned.size() >= 9


## Cars the player can choose: the own car first, then the won ones.
func choices() -> Array[int]:
	var out: Array[int] = [OWN_CAR]
	out.append_array(owned)
	return out


## Championship reward: one random rival car the player does not own yet
## (saved at once). Returns its racer id, or -1 when all nine are owned.
func unlock_random(rng: RandomNumberGenerator) -> int:
	var left: Array[int] = []
	for id in range(1, 10):
		if not owned.has(id):
			left.append(id)
	if left.is_empty():
		return -1
	var id := left[rng.randi_range(0, left.size() - 1)]
	owned.append(id)
	save()
	return id


## A championship started: the next one uses the next schedule (saved).
func count_championship() -> void:
	championships_run += 1
	save()


## Forget everything (tests, a reset).
func clear() -> void:
	owned.clear()
	championships_run = 0
	save()
