class_name RaceSnapshot
extends RefCounted
## Authoritative race state the host sends to the client (M5.1): every car's
## pose, motion and presence, each racer's laps / progress / finish, the race
## clock and state, and (with weapons) the combat state. Plain arrays only, so
## var_to_bytes encodes them compactly and safely. Pure functions: capture on
## the host, apply on the client.

const CAR_FIELDS := 6     # x, y, heading, vx, vy, present
const RACER_FIELDS := 6   # laps, next checkpoint, progress, finish position, finish time, lap start


static func capture(race: Node, tick: int) -> Array:
	var cars := PackedFloat32Array()
	for c: Car in race.cars:
		cars.append_array([c.global_position.x, c.global_position.y, c.model.heading,
			c.model.velocity.x, c.model.velocity.y, 1.0 if c.visible else 0.0])
	var session: RaceSession = race.session
	var racers := PackedFloat64Array()
	for r in session.racers:
		racers.append_array([r.tracker.laps_completed, r.tracker.next_checkpoint, r.progress,
			r.finish_position, r.finish_time, r.lap_start])
	return [tick, session.state, session.elapsed, cars, racers, PackedInt32Array(session.finish_order)]


static func encode(snap: Array) -> PackedByteArray:
	return var_to_bytes(snap)


## Empty when the bytes are not an encoded array (checked before decoding).
static func decode(bytes: PackedByteArray) -> Array:
	if bytes.size() < 8 or (bytes.decode_u32(0) & 0xFF) != TYPE_ARRAY:
		return []
	var v: Variant = bytes_to_var(bytes)
	return v if v is Array else []


static func tick_of(snap: Array) -> int:
	return snap[0]


## Car c's [position, heading, velocity, present] in a snapshot.
static func car_state(snap: Array, c: int) -> Dictionary:
	var a: PackedFloat32Array = snap[3]
	var k := c * CAR_FIELDS
	return {"position": Vector2(a[k], a[k + 1]), "heading": a[k + 2], "velocity": Vector2(a[k + 3], a[k + 4]),
		"present": a[k + 5] > 0.5}


## Applies everything except car poses (those are interpolated by the client).
static func apply_race(race: Node, snap: Array) -> void:
	var session: RaceSession = race.session
	session.state = snap[1]
	session.elapsed = snap[2]
	var racers: PackedFloat64Array = snap[4]
	for i in session.racers.size():
		var r := session.racers[i]
		var k := i * RACER_FIELDS
		if k + RACER_FIELDS > racers.size():
			break
		r.tracker.laps_completed = int(racers[k])
		r.tracker.next_checkpoint = int(racers[k + 1])
		r.progress = racers[k + 2]
		r.finish_position = int(racers[k + 3])
		r.finish_time = racers[k + 4]
		r.lap_start = racers[k + 5]
	var order: Array[int] = []
	for id in snap[5]:
		order.append(id)
	session.finish_order = order
