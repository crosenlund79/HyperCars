class_name DriverInput
extends RefCounted
## One car's controls for one fixed tick, the same for every kind of driver:
## steer (-1, 0, +1) and fire for driving, plus front / rear weapon requests.
## Implementations: HumanDriverInput (local device), AiDriverInput (computer
## driver). A future network driver only has to replay received commands.
## The race scene applies every command identically (same car model, same
## combat rules), so humans and AI can never drift apart.

var racer_id := -1


func is_human() -> bool:
	return false


## Called when a race starts (seed = the race's decision seed for this racer).
func begin_race(_seed: int) -> void:
	pass


## Driving command for this tick: {steer: float, fire: bool}.
func drive(_race: Node, _step: float) -> Dictionary:
	return {"steer": 0.0, "fire": false}


## Weapon requests for this tick: {front: bool, rear: bool}. `states` is the
## combat view of every car (CombatWorld.step format).
func weapons(_race: Node, _step: float, _states: Array) -> Dictionary:
	return {"front": false, "rear": false}


## The car was destroyed.
func on_destroyed() -> void:
	pass
