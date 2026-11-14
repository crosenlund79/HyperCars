class_name AiDriver
extends RefCounted
## One computer driver. Each tick it reads its car's state and nearby traffic and
## returns the same inputs a player has: steer (-1, 0, +1) and fire. It drives in
## Fire to Accelerate mode: fire accelerates, releasing fire brakes.
## Personality traits in AiParams shape decisions only (braking point, corner
## commitment, passing, reactions to pressure); with neutral traits this is the
## M2 driver. Randomness comes from a per-race seeded generator.
## Pure logic (no scene access), so it is unit-testable.

var line: RacingLine
var params: AiParams
var rng := RandomNumberGenerator.new()
## Current sideways shift from the racing line (px), used for passing.
var lane_bias := 0.0
## Commitment chosen for the current corner (1.0 outside corners).
var commitment := 1.0
## True while the driver is in a braking/corner zone.
var in_corner := false
## Seconds of fluster left (hesitation / over-correction under pressure).
var fluster_time := 0.0
## Seconds left of reduced commitment after the planned line was disrupted.
var disrupted_time := 0.0
## Side chosen for the current pass attempt (-1/+1, 0 = none).
var pass_side_choice := 0.0
var _was_passing := false
## Counters for validation and tests.
var overcommits := 0
var flusters := 0
var defends := 0
var disruptions := 0
var impulse_passes := 0
var _defending := false


func _init(p_line: RacingLine, p_params: AiParams) -> void:
	line = p_line
	params = p_params
	begin_race(0)


## Resets per-race state and seeds the decision randomness.
func begin_race(seed_value: int) -> void:
	rng.seed = seed_value
	lane_bias = 0.0
	commitment = 1.0
	in_corner = false
	fluster_time = 0.0
	overcommits = 0
	flusters = 0
	disrupted_time = 0.0
	pass_side_choice = 0.0
	_was_passing = false
	defends = 0
	disruptions = 0
	impulse_passes = 0
	_defending = false


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
	var passing := false
	if not ahead.is_empty():
		var pass_lateral := NAN
		var wants: bool = ahead.speed < speed - params.pass_speed_margin
		if not wants and params.pass_impulse_chance > 0.0 and rng.randf() < params.pass_impulse_chance * delta:
			wants = true
			impulse_passes += 1
		if wants and _may_start_pass(s):
			pass_lateral = _pass_lateral(me, ahead, others, s)
		if not is_nan(pass_lateral):
			blocked = true
			passing = true
			target_lateral = pass_lateral
		elif ahead.gap < params.follow_gap:
			lift = true
	_was_passing = passing
	if not passing and params.defend_distance > 0.0:
		var chaser := _closing_car_behind(me, others)
		if not chaser.is_empty():
			var limit_d := line.road_half_width - params.pass_margin
			target_lateral = lerpf(target_lateral, clampf(chaser.lateral, -limit_d, limit_d), params.defend_strength)
			blocked = true
			if not _defending:
				defends += 1
			_defending = true
		else:
			_defending = false

	_update_fluster(me, others, delta)
	var flustered := fluster_time > 0.0
	if flustered and params.fluster_lift_chance > 0.0 and rng.randf() < params.fluster_lift_chance:
		lift = true

	var desired_bias := target_lateral - line.offset_at(s)
	var rate := params.lane_change_rate if blocked else params.lane_return_rate
	lane_bias = move_toward(lane_bias, desired_bias, rate * delta)

	var lookahead := params.lookahead_base + params.lookahead_per_speed * speed
	var deadband := deg_to_rad(params.steer_deadband_degrees)
	if flustered:
		lookahead *= 1.0 - params.fluster_overcorrection
		deadband *= 1.0 - params.fluster_overcorrection
	var limit := line.road_half_width - params.pass_margin
	var aim_lateral := clampf(line.offset_at(s + lookahead) + lane_bias, -limit, limit)
	var aim := line.point_with_lateral(s + lookahead, aim_lateral)
	var error := wrapf((aim - me.position).angle() - me.heading, -PI, PI)
	var steer := 0.0
	if absf(error) > deadband:
		steer = signf(error)

	var speed_point := s + speed * params.brake_anticipation
	var planned := line.speed_at(speed_point)
	_update_corner(planned < line.top_speed - 1.0, not _nearest_car_ahead(me, others, true).is_empty())
	var target_speed := planned * commitment if in_corner else planned
	if in_corner and _defending:
		target_speed *= params.defend_commitment
	if params.disrupted_threshold > 0.0:
		disrupted_time = maxf(0.0, disrupted_time - delta)
		if absf(lane_bias) > params.disrupted_threshold and not passing:
			if disrupted_time <= 0.0:
				disruptions += 1
			disrupted_time = params.disrupted_recovery
		if in_corner and disrupted_time > 0.0:
			target_speed *= params.disrupted_commitment
	var fire := speed < target_speed and not lift
	return {"steer": steer, "fire": fire}


## Picks this corner's commitment when entering a braking/corner zone.
func _update_corner(zone: bool, chasing: bool) -> void:
	if zone and not in_corner:
		commitment = params.corner_commitment
		if params.commitment_variation > 0.0:
			commitment += rng.randf_range(-params.commitment_variation, params.commitment_variation)
		if params.overcommit_chance > 0.0 and rng.randf() < params.overcommit_chance:
			commitment += params.overcommit_extra
			overcommits += 1
		if chasing:
			commitment += params.chase_aggression
	elif not zone:
		commitment = 1.0
	in_corner = zone


## Under pressure (a car close behind or alongside) the driver may become flustered.
func _update_fluster(me: Dictionary, others: Array, delta: float) -> void:
	fluster_time = maxf(0.0, fluster_time - delta)
	if params.pressure_distance <= 0.0 or fluster_time > 0.0:
		return
	if under_pressure(me, others) and rng.randf() < params.fluster_chance_per_second * delta:
		fluster_time = params.fluster_duration
		flusters += 1


func under_pressure(me: Dictionary, others: Array) -> bool:
	if params.pressure_distance <= 0.0:
		return false
	for o in others:
		var gap := _gap(me, o)
		if gap <= 0.0 and gap > -params.pressure_distance and absf(o.lateral - me.lateral) < params.car_clearance * 2.0:
			return true
	return false


## Pass position honouring the driver's side preference and lane-clearance check.
func _pass_lateral(me: Dictionary, ahead: Dictionary, others: Array, s: float) -> float:
	var lateral := choose_pass_lateral(me.lateral, ahead.lateral)
	if params.pass_side != 0:
		if not _was_passing or pass_side_choice == 0.0:
			if params.pass_side == 2:
				pass_side_choice = -1.0 if rng.randf() < 0.5 else 1.0
			else:
				pass_side_choice = -_turn_direction(s)
		var candidate: float = ahead.lateral + pass_side_choice * params.pass_offset
		if absf(candidate) <= line.road_half_width - params.pass_margin:
			lateral = candidate
	if not is_nan(lateral) and params.pass_check_clearance:
		for o in others:
			var gap := _gap(me, o)
			if is_equal_approx(gap, ahead.gap) and is_equal_approx(o.lateral, ahead.lateral):
				continue
			if gap > -60.0 and gap < params.traffic_distance and absf(o.lateral - lateral) < params.car_clearance:
				return NAN
	return lateral


## Sign of the next corner's turn (+1 right, -1 left, 0 straight) within pass_lookahead + 300 px.
func _turn_direction(s: float) -> float:
	var t0 := line.center.tangent_at(s)
	var d := 100.0
	while d <= params.pass_lookahead + 300.0:
		var t1 := line.center.tangent_at(s + d)
		var turn := t0.cross(t1)
		if absf(turn) > 0.2:
			return signf(turn)
		d += 50.0
	return 0.0


## Nearest car behind within defend_distance that is at least as fast; empty if none.
func _closing_car_behind(me: Dictionary, others: Array) -> Dictionary:
	var best := {}
	for o in others:
		var gap := _gap(me, o)
		if gap >= 0.0 or gap < -params.defend_distance or o.speed < me.speed - 10.0:
			continue
		if best.is_empty() or gap > best.gap:
			best = {"gap": gap, "lateral": o.lateral, "speed": o.speed}
	return best


func _may_start_pass(s: float) -> bool:
	if not params.pass_on_straights_only:
		return true
	var d := 0.0
	while d <= params.pass_lookahead:
		if line.speed_at(s + d) < line.top_speed - 1.0:
			return false
		d += 50.0
	return true


func _gap(me: Dictionary, other: Dictionary) -> float:
	return wrapf(other.distance - me.distance, -line.center.length * 0.5, line.center.length * 0.5)


## Closest car ahead within traffic_distance, as {gap, lateral, speed}; empty if none.
## Only cars in our path count unless any_lane is true.
func _nearest_car_ahead(me: Dictionary, others: Array, any_lane: bool = false) -> Dictionary:
	var best := {}
	for o in others:
		var gap := _gap(me, o)
		if gap <= 0.0 or gap > params.traffic_distance:
			continue
		if not any_lane and absf(o.lateral - me.lateral) > params.car_clearance:
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
