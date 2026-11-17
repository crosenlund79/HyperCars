class_name PitWorld
extends RefCounted
## Pit lanes for one race (pure per-car state, host-authoritative): the pit
## limiter, deliberate overrides with their speeding ticket, the sporting
## penalty, and free service in the service box. The race scene feeds it each
## tick where every car is (in the pit lane / in the box), its speed and
## condition; it answers with speed caps, repairs and events.
##
## One pit-lane traversal = from entering the pit lane proper (beside the
## divider) to leaving it. Per traversal: at most one override, one ticket and
## one service. Leaving the lane and coming back in a later lap starts a new
## traversal; nudging out of the box and back in does not.

var rules: PitRules
## Per car.
var in_lane := PackedByteArray()
var overridden := PackedByteArray()
var ticketed := PackedByteArray()
var served := PackedByteArray()
## Seconds of service done (0 = none in progress) and penalty still to serve.
var service := PackedFloat32Array()
var penalty_left := PackedFloat32Array()
## Garage races: the human's fines this race ($), settled with the prize.
var fines := PackedInt32Array()
## Per car: 1 = pays a fine (the human in a garage race), 0 = serves the
## sporting penalty instead (other modes, every rival).
var pays_fines := PackedByteArray()
## Service in the pits is allowed in this race (off in Knockout).
var service_enabled := true
## Pit stops and tickets per car (statistics, tests).
var stops := PackedInt32Array()
var tickets := PackedInt32Array()


func _init(p_rules: PitRules, car_count: int) -> void:
	rules = p_rules
	for arr in [in_lane, overridden, ticketed, served]:
		arr.resize(car_count)
	for arr in [service, penalty_left]:
		arr.resize(car_count)
	fines.resize(car_count)
	pays_fines.resize(car_count)
	stops.resize(car_count)
	tickets.resize(car_count)
	reset()


func reset() -> void:
	for arr in [in_lane, overridden, ticketed, served]:
		arr.fill(0)
	service.fill(0.0)
	penalty_left.fill(0.0)
	fines.fill(0)
	stops.fill(0)
	tickets.fill(0)


func car_count() -> int:
	return in_lane.size()


## The limiter holds this car now (in the lane and not overridden).
func limiter_on(id: int) -> bool:
	return in_lane[id] == 1 and overridden[id] == 0


## The car must keep to the limiter speed: the limiter, or a penalty after a ticket.
func limited(id: int) -> bool:
	return limiter_on(id) or penalty_left[id] > 0.0


## Service progress 0 .. 1 (0 = none).
func service_progress(id: int) -> float:
	return clampf(service[id] / maxf(rules.service_time, 0.01), 0.0, 1.0)


## A deliberate override (a human's double tap, a rival's choice): only in the
## pit lane, once per traversal. Returns true when it was granted (and the
## ticket issued: the caller logs the event and the penalty).
func request_override(id: int) -> bool:
	if in_lane[id] == 0 or overridden[id] == 1:
		return false
	overridden[id] = 1
	if ticketed[id] == 0:
		ticketed[id] = 1
		tickets[id] += 1
		if pays_fines[id] == 1:
			fines[id] += rules.fine
	return true


## One tick for one car. lane / box: where it is; speed (px/s); condition and
## max_condition (points); out: retired (DNF) or not racing (no service).
## Returns the condition points to add (> 0 when a service just completed).
func step(id: int, lane: bool, box: bool, speed: float, condition: float, max_condition: float,
		out: bool, delta: float) -> float:
	if penalty_left[id] > 0.0:
		penalty_left[id] = maxf(0.0, penalty_left[id] - delta)
	if lane and in_lane[id] == 0:  # a new traversal of the pit lane
		in_lane[id] = 1
		overridden[id] = 0
		ticketed[id] = 0
		served[id] = 0
		service[id] = 0.0
	elif not lane and in_lane[id] == 1:  # out of the pit lane
		in_lane[id] = 0
		service[id] = 0.0
		if ticketed[id] == 1 and pays_fines[id] == 0:
			penalty_left[id] = rules.penalty_time  # the sporting penalty, served on the track
	if not lane:
		return 0.0
	var can_serve := service_enabled and not out and served[id] == 0 and condition < max_condition
	if box and speed <= rules.stopped_speed and can_serve:
		service[id] += delta
		if service[id] >= rules.service_time:
			service[id] = 0.0
			served[id] = 1
			stops[id] += 1
			return minf(rules.repair_points * max_condition / 100.0, max_condition - condition)
	else:
		service[id] = 0.0  # moved off or out of the box: the service is interrupted
	return 0.0


## Compact per-car state for network snapshots: bit 0 limiter on, bit 1
## overridden (in the lane), bit 2 penalty, bits 3-7 service progress (0 .. 31).
func pack(id: int) -> int:
	var v := (1 if limiter_on(id) else 0) | ((in_lane[id] & overridden[id]) << 1) | ((1 if penalty_left[id] > 0.0 else 0) << 2)
	return v | (int(round(service_progress(id) * 31.0)) << 3)
