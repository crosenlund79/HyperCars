class_name RivalRoster
extends RefCounted
## The nine recurring rivals. Racer id n (1..9) is always the same driver, car
## colour (cars/car_ai_n) and personality, in every race and every session.
## Drivers without a personality file use the shared default AI (pending the
## personality pilot's approval).

const DEFAULT_PARAMS := "res://src/ai/default_ai_params.tres"
const RIVALS := [
	{"name": "Victor", "nickname": "The Professor", "params": "res://src/ai/personalities/victor.tres"},
	{"name": "Rocco", "nickname": "Mad Dog", "params": "res://src/ai/personalities/rocco.tres"},
	{"name": "Ellie", "nickname": "Sparrow", "params": "res://src/ai/personalities/ellie.tres"},
	{"name": "Hank", "nickname": "The Wall", "params": ""},
	{"name": "Maya", "nickname": "Ghost", "params": ""},
	{"name": "Dante", "nickname": "Showboat", "params": ""},
	{"name": "Greta", "nickname": "Clockwork", "params": ""},
	{"name": "Finn", "nickname": "Wildcard", "params": ""},
	{"name": "Nina", "nickname": "The Hunter", "params": ""},
]


static func count() -> int:
	return RIVALS.size()


## Short name used in tables, e.g. "Victor".
static func short_name(id: int) -> String:
	return RIVALS[id - 1].name


## Full name, e.g. Victor "The Professor".
static func full_name(id: int) -> String:
	return '%s "%s"' % [RIVALS[id - 1].name, RIVALS[id - 1].nickname]


static func params_path(id: int) -> String:
	var path: String = RIVALS[id - 1].params
	return path if not path.is_empty() else DEFAULT_PARAMS


static func has_personality(id: int) -> bool:
	return not String(RIVALS[id - 1].params).is_empty()
