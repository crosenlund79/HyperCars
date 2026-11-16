class_name RaceSnapshot
extends RefCounted
## Authoritative race state the host sends to the client (M5.1): every car's
## pose, motion and presence, each racer's laps / progress / finish, the race
## clock and state, and (with weapons) the combat state. M6: each car's
## condition and each racer's DNF. Plain arrays only, so
## var_to_bytes encodes them compactly and safely. Pure functions: capture on
## the host, apply on the client.

const CAR_FIELDS := 7     # x, y, heading, vx, vy, present, condition
const RACER_FIELDS := 7   # laps, next checkpoint, progress, finish position, finish time, lap start, dnf


static func capture(race: Node, tick: int) -> Array:
	var cars := PackedFloat32Array()
	var damage: DamageWorld = race.damage
	for c: Car in race.cars:
		cars.append_array([c.global_position.x, c.global_position.y, c.model.heading,
			c.model.velocity.x, c.model.velocity.y, 1.0 if c.visible else 0.0, damage.condition[c.racer_id]])
	var session: RaceSession = race.session
	var racers := PackedFloat32Array()
	for r in session.racers:
		racers.append_array([r.tracker.laps_completed, r.tracker.next_checkpoint, r.progress,
			r.finish_position, r.finish_time, r.lap_start, 1.0 if r.dnf else 0.0])
	var snap := [tick, session.state, session.elapsed, cars, racers, PackedInt32Array(session.finish_order)]
	var combat: CombatWorld = race.combat
	if combat.enabled:
		snap.append(capture_combat(combat))
	return snap


static func capture_combat(combat: CombatWorld) -> Array:
	var ammo := PackedByteArray()  # rounds (max 99) and weapon types fit in a byte
	var timers := PackedFloat32Array()
	for i in combat.car_count():
		ammo.append_array([clampi(combat.ammo[i][0], 0, 255), clampi(combat.ammo[i][1], 0, 255), combat.loadout[i][0], combat.loadout[i][1]])
		timers.append_array([combat.cooldown[i], combat.wreck_left[i], combat.grace_left[i],
			combat.slot_cooldown[i][0], combat.slot_cooldown[i][1]])
	var shots := PackedFloat32Array()
	for p in combat.projectiles:
		shots.append_array([p.type, p.owner, p.pos.x, p.pos.y, p.dir.x, p.dir.y, p.get("angle", 0.0), p.age])
	var mines := PackedFloat32Array()
	for m in combat.mines:
		mines.append_array([m.owner, m.pos.x, m.pos.y, m.age])
	return [ammo, timers, shots, mines]


static func encode(snap: Array) -> PackedByteArray:
	return var_to_bytes(snap)


## Empty when the bytes are not an encoded array (checked before decoding).
static func decode(bytes: PackedByteArray) -> Array:
	if bytes.size() < 8 or (bytes.decode_u32(0) & 0xFF) != TYPE_ARRAY:
		return []
	var v: Variant = bytes_to_var(bytes)
	return v if v is Array else []


## Structure check before a received snapshot is used.
static func is_valid(snap: Array, car_count: int, racer_count: int) -> bool:
	if snap.size() < 6 or snap.size() > 7:
		return false
	if typeof(snap[0]) != TYPE_INT or typeof(snap[1]) != TYPE_INT or snap[1] < 0 or snap[1] > 2:
		return false
	if not snap[3] is PackedFloat32Array or snap[3].size() != car_count * CAR_FIELDS:
		return false
	if not snap[4] is PackedFloat32Array or snap[4].size() != racer_count * RACER_FIELDS:
		return false
	if not snap[5] is PackedInt32Array:
		return false
	return snap.size() == 6 or snap[6] is Array


static func tick_of(snap: Array) -> int:
	return snap[0]


## Car c's [position, heading, velocity, present] in a snapshot.
static func car_state(snap: Array, c: int) -> Dictionary:
	var a: PackedFloat32Array = snap[3]
	var k := c * CAR_FIELDS
	return {"position": Vector2(a[k], a[k + 1]), "heading": a[k + 2], "velocity": Vector2(a[k + 3], a[k + 4]),
		"present": a[k + 5] > 0.5}


## Applies the race state except car poses and combat (those follow the
## client's interpolated moment; see NetRace).
static func apply_race(race: Node, snap: Array) -> void:
	var session: RaceSession = race.session
	session.state = snap[1]
	session.elapsed = snap[2]
	var racers: PackedFloat32Array = snap[4]
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
		r.dnf = racers[k + 6] > 0.5
	var damage: DamageWorld = race.damage
	var cars: PackedFloat32Array = snap[3]
	for c in damage.car_count():
		var k := c * CAR_FIELDS + 6
		if k >= cars.size():
			break
		var cond := clampf(cars[k], 0.0, damage.rules.max_condition)
		if cond < damage.condition[c] - 0.01:
			damage.since_hit[c] = 0.0  # hit flash on this computer too
		damage.condition[c] = cond
		damage.retired[c] = 1 if cond <= 0.0 else 0
	var order: Array[int] = []
	for id in snap[5]:
		order.append(id)
	session.finish_order = order


static func apply_combat(combat: CombatWorld, c: Array) -> void:
	var ammo: PackedByteArray = c[0]
	var timers: PackedFloat32Array = c[1]
	for i in combat.car_count():
		combat.ammo[i] = [ammo[i * 4], ammo[i * 4 + 1]]
		combat.loadout[i] = [ammo[i * 4 + 2], ammo[i * 4 + 3]]
		combat.cooldown[i] = timers[i * 5]
		combat.wreck_left[i] = timers[i * 5 + 1]
		combat.grace_left[i] = timers[i * 5 + 2]
		combat.slot_cooldown[i] = [timers[i * 5 + 3], timers[i * 5 + 4]]
	var shots: PackedFloat32Array = c[2]
	var projectiles: Array = []
	for k in range(0, shots.size(), 8):
		projectiles.append({"type": int(shots[k]), "owner": int(shots[k + 1]), "pos": Vector2(shots[k + 2], shots[k + 3]),
			"dir": Vector2(shots[k + 4], shots[k + 5]), "angle": shots[k + 6], "age": shots[k + 7], "target": -1})
	combat.projectiles = projectiles
	var mine_data: PackedFloat32Array = c[3]
	var mines: Array = []
	for k in range(0, mine_data.size(), 4):
		mines.append({"owner": int(mine_data[k]), "pos": Vector2(mine_data[k + 1], mine_data[k + 2]), "age": mine_data[k + 3]})
	combat.mines = mines
