class_name AiDriver
extends RefCounted
## One computer driver. Each tick it reads its car's state and nearby traffic and
## returns the same inputs a player has: steer (-1, 0, +1) and fire. It drives in
## Fire to Accelerate mode: fire accelerates, releasing fire brakes.
## Pure logic (no scene access), so it is unit-testable.

var line: RacingLine
var params: AiParams
## Current sideways shift from the racing line (px), used for passing.
var lane_bias := 0.0


func _init(p_line: RacingLine, p_params: AiParams) -> void:
	line = p_line
	params = p_params


## me: {position, heading, speed, distance, lateral}
## others: Array of {distance, lateral, speed} for the other cars.
## distance values are unwrapped race progress along the centreline.
## Returns {steer: float, fire: bool}.
func decide(me: Dictionary, others: Array, delta: float) -> Dictionary:
	var s: float = me.distance
	var speed: float = me.speed
	var target_lateral := line.offset_at(s)
	var blocked := false
	var lift := false

	var ahead := _nearest_car_ahead(me, others)
	if not ahead.is_empty():
		var pass_lateral := NAN
		if ahead.speed < speed - params.pass_speed_margin:
			pass_lateral = choose_pass_lateral(me.lateral, ahead.lateral)
		if not is_nan(pass_lateral):
			blocked = true
			target_lateral = pass_lateral
		elif ahead.gap < params.follow_gap:
			lift = true

	var desired_bias := target_lateral - line.offset_at(s)
	var rate := params.lane_change_rate if blocked else params.lane_return_rate
	lane_bias = move_toward(lane_bias, desired_bias, rate * delta)

	var lookahead := params.lookahead_base + params.lookahead_per_speed * speed
	var limit := line.road_half_width - params.pass_margin
	var aim_lateral := clampf(line.offset_at(s + lookahead) + lane_bias, -limit, limit)
	var aim := line.point_with_lateral(s + lookahead, aim_lateral)
	var error := wrapf((aim - me.position).angle() - me.heading, -PI, PI)
	var steer := 0.0
	if absf(error) > deg_to_rad(params.steer_deadband_degrees):
		steer = signf(error)

	var target_speed := line.speed_at(s + speed * 0.1)
	var fire := speed < target_speed and not lift
	return {"steer": steer, "fire": fire}


## Closest car in our path within traffic_distance, as {gap, lateral, speed}; empty if none.
func _nearest_car_ahead(me: Dictionary, others: Array) -> Dictionary:
	var best := {}
	for o in others:
		var gap := wrapf(o.distance - me.distance, -line.center.length * 0.5, line.center.length * 0.5)
		if gap <= 0.0 or gap > params.traffic_distance:
			continue
		if absf(o.lateral - me.lateral) > params.car_clearance:
			continue
		if best.is_empty() or gap < best.gap:
			best = {"gap": gap, "lateral": o.lateral, "speed": o.speed}
	return best


## Lateral position to pass a car at other_lateral: the side with room that is
## closest to where we are. NAN when neither side has room inside the road.
func choose_pass_lateral(my_lateral: float, other_lateral: float) -> float:
	var options: Array[float] = []
	var limit := line.road_half_width - params.pass_margin
	for side in [-1.0, 1.0]:
		var candidate: float = other_lateral + side * params.pass_offset
		if absf(candidate) <= limit:
			options.append(candidate)
	if options.is_empty():
		return NAN
	options.sort_custom(func(a: float, b: float) -> bool: return absf(a - my_lateral) < absf(b - my_lateral))
	return options[0]
