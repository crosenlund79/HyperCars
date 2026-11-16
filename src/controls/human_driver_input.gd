class_name HumanDriverInput
extends DriverInput
## A human driver on this machine. Reads one set of input actions: the default
## single-player actions (prefix "") or a player's own device-bound actions
## (e.g. "p2_", see PlayerControls.ensure_player_actions).

var prefix := ""


func _init(p_racer_id: int, p_prefix: String = "") -> void:
	racer_id = p_racer_id
	prefix = p_prefix


func is_human() -> bool:
	return true


## While racing: the player's joystick. After this driver's flag the player has
## no control and the car brakes to a stop.
func drive(race: Node, _step: float) -> Dictionary:
	var car: Car = race.cars[racer_id]
	if race.session.racers[racer_id].is_finished() or race.menu_open:  # menu open: brake, no steering
		return {"steer": 0.0, "fire": car.model.control_mode == CarModel.ControlMode.FIRE_TO_BRAKE}
	return {"steer": PlayerControls.steer(prefix), "fire": PlayerControls.fire_held(prefix)}


## Joystick Forward / Backwards presses, only while racing and not wrecked.
func weapons(race: Node, _step: float, _states: Array) -> Dictionary:
	var out := {"front": false, "rear": false}
	if race.session.state != RaceSession.State.RACING or race.combat.is_wrecked(racer_id) \
			or race.session.racers[racer_id].is_finished() or race.menu_open:
		return out
	out.front = Input.is_action_just_pressed(prefix + PlayerControls.FIRE_FRONT)
	out.rear = Input.is_action_just_pressed(prefix + PlayerControls.FIRE_REAR)
	return out
