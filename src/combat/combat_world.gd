class_name CombatWorld
extends RefCounted
## Deterministic combat simulation: ammunition, cooldowns, missiles, mines,
## the super missile, hits, wrecks and respawns. Pure logic (no physics bodies,
## no randomness), advanced once per fixed physics tick, so fast simulation and
## tests reproduce it exactly. Every car follows exactly the same rules.
## Projectiles explode on a car within hit_radius or at the barrier line.

const FRONT := 0
const REAR := 1
const W := WeaponRules.Weapon

var rules: WeaponRules
var enabled := false
var path: ClosedPath
var road_half_width := 75.0
## Per car: ammo [front, rear], cooldown, wreck and grace timers, counters.
var ammo: Array = []
var cooldown := PackedFloat32Array()
var wreck_left := PackedFloat32Array()
var grace_left := PackedFloat32Array()
var destroyed_count := PackedInt32Array()
var shots_fired := PackedInt32Array()
## Live projectiles: {type, owner, pos, dir, age, target, angle}.
var projectiles: Array = []
## Live mines: {owner, pos, age}.
var mines: Array = []
## Append-only event log for presentation: {kind, type, pos, car, owner}.
## kinds: fire, empty, explode, destroyed, respawn, mine_blast.
var events: Array = []


func _init(p_rules: WeaponRules, car_count: int, p_path: ClosedPath = null, p_road_half_width := 75.0) -> void:
	rules = p_rules
	path = p_path
	road_half_width = p_road_half_width
	cooldown.resize(car_count)
	wreck_left.resize(car_count)
	grace_left.resize(car_count)
	destroyed_count.resize(car_count)
	shots_fired.resize(car_count)
	reset()


## New race: full ammunition, no projectiles, nobody wrecked.
func reset() -> void:
	ammo.clear()
	for i in cooldown.size():
		ammo.append([rules.ammo_for(FRONT), rules.ammo_for(REAR)])
	cooldown.fill(0.0)
	wreck_left.fill(0.0)
	grace_left.fill(0.0)
	destroyed_count.fill(0)
	shots_fired.fill(0)
	projectiles.clear()
	mines.clear()
	events.clear()


func car_count() -> int:
	return cooldown.size()


func is_wrecked(id: int) -> bool:
	return wreck_left[id] > 0.0


func can_fire(id: int, slot: int) -> bool:
	return enabled and not is_wrecked(id) and cooldown[id] <= 0.0 and ammo[id][slot] > 0 \
		and rules.weapon_for(slot) != W.NONE


## Fire request from a car (player key or AI decision). cars: see step().
## Returns true when a weapon was launched.
func request(id: int, slot: int, cars: Array) -> bool:
	if not enabled or is_wrecked(id) or cooldown[id] > 0.0:
		return false
	var weapon := rules.weapon_for(slot)
	if weapon == W.NONE:
		return false
	if ammo[id][slot] <= 0:
		events.append({"kind": "empty", "type": weapon, "pos": cars[id].position, "car": id, "owner": id})
		cooldown[id] = rules.fire_cooldown
		return false
	ammo[id][slot] -= 1
	cooldown[id] = rules.fire_cooldown
	shots_fired[id] += 1
	var c: Dictionary = cars[id]
	var fwd := Vector2.from_angle(c.heading)
	match weapon:
		W.FRONT_MISSILE, W.HOMING_MISSILE:
			var p := {"type": weapon, "owner": id, "pos": c.position + fwd * 36.0, "dir": fwd, "age": 0.0, "target": -1}
			if weapon == W.HOMING_MISSILE:
				p.target = nearest_car(id, cars)
			projectiles.append(p)
		W.REAR_MISSILE:
			projectiles.append({"type": weapon, "owner": id, "pos": c.position - fwd * 36.0, "dir": -fwd, "age": 0.0, "target": -1})
		W.SUPER_MISSILE:
			projectiles.append({"type": weapon, "owner": id, "pos": c.position + fwd * rules.super_orbit_radius,
				"dir": fwd, "age": 0.0, "target": -1, "angle": c.heading})
		W.MINE:
			mines.append({"owner": id, "pos": c.position - fwd * 34.0, "age": 0.0})
	events.append({"kind": "fire", "type": weapon, "pos": c.position, "car": id, "owner": id})
	return true


## Nearest other car that is not wrecked (-1 if none within homing_range).
func nearest_car(id: int, cars: Array) -> int:
	var best := -1
	var best_d := rules.homing_range
	for j in cars.size():
		if j == id or is_wrecked(j) or not cars[j].present:
			continue
		var d: float = cars[id].position.distance_to(cars[j].position)
		if d < best_d:
			best_d = d
			best = j
	return best


## Advances one tick. cars[i] = {position, heading, present}. present = false for
## cars not in the race (e.g. the player when spectating).
## Returns {destroyed: [ids], respawned: [ids]}.
func step(dt: float, cars: Array) -> Dictionary:
	var destroyed: Array[int] = []
	var respawned: Array[int] = []
	if not enabled:
		return {"destroyed": destroyed, "respawned": respawned}
	for i in cooldown.size():
		cooldown[i] = maxf(0.0, cooldown[i] - dt)
		grace_left[i] = maxf(0.0, grace_left[i] - dt)
		if wreck_left[i] > 0.0:
			wreck_left[i] = maxf(0.0, wreck_left[i] - dt)
			if wreck_left[i] <= 0.0:
				grace_left[i] = rules.respawn_grace
				respawned.append(i)
				events.append({"kind": "respawn", "type": W.NONE, "pos": cars[i].position, "car": i, "owner": i})
	var alive: Array = []
	for p in projectiles:
		p.age += dt
		var keep := true
		match p.type:
			W.SUPER_MISSILE:
				var owner_car: Dictionary = cars[p.owner]
				p.angle += deg_to_rad(rules.super_orbit_speed_degrees) * dt
				p.pos = owner_car.position + Vector2.from_angle(p.angle) * rules.super_orbit_radius
				if p.age >= rules.super_duration or is_wrecked(p.owner):
					keep = false
					events.append({"kind": "explode", "type": p.type, "pos": p.pos, "car": -1, "owner": p.owner})
				else:
					for j in cars.size():
						if j != p.owner and cars[j].present and p.pos.distance_to(cars[j].position) < rules.super_hit_radius:
							_hit(j, p, destroyed)
			_:
				if p.type == W.HOMING_MISSILE and p.target >= 0 and not is_wrecked(p.target):
					var want: Vector2 = (cars[p.target].position - p.pos).normalized()
					var turn := clampf(p.dir.angle_to(want), -deg_to_rad(rules.homing_turn_rate_degrees) * dt,
						deg_to_rad(rules.homing_turn_rate_degrees) * dt)
					p.dir = p.dir.rotated(turn)
				p.pos += p.dir * rules.missile_speed * dt
				if p.age >= rules.missile_lifetime:
					keep = false
					events.append({"kind": "explode", "type": p.type, "pos": p.pos, "car": -1, "owner": p.owner})
				else:
					var hit := _car_at(p.pos, rules.hit_radius, cars, p.owner if p.age < 0.25 else -1)
					if hit >= 0:
						keep = false
						_hit(hit, p, destroyed)
					elif _outside_road(p):
						keep = false
						events.append({"kind": "explode", "type": p.type, "pos": p.pos, "car": -1, "owner": p.owner})
		if keep:
			alive.append(p)
	projectiles = alive
	var live_mines: Array = []
	for m in mines:
		m.age += dt
		if m.age >= rules.mine_fuse:
			events.append({"kind": "mine_blast", "type": W.MINE, "pos": m.pos, "car": -1, "owner": m.owner})
			for j in cars.size():
				if cars[j].present and m.pos.distance_to(cars[j].position) <= rules.mine_blast_radius:
					_destroy(j, m.owner, m.pos, W.MINE, destroyed)
		else:
			live_mines.append(m)
	mines = live_mines
	return {"destroyed": destroyed, "respawned": respawned}


func _hit(car: int, p: Dictionary, destroyed: Array[int]) -> void:
	events.append({"kind": "explode", "type": p.type, "pos": p.pos, "car": car, "owner": p.owner})
	_destroy(car, p.owner, p.pos, p.type, destroyed)


func _destroy(car: int, owner: int, pos: Vector2, type: int, destroyed: Array[int]) -> void:
	if is_wrecked(car) or grace_left[car] > 0.0:
		return
	wreck_left[car] = rules.wreck_time
	destroyed_count[car] += 1
	destroyed.append(car)
	events.append({"kind": "destroyed", "type": type, "pos": pos, "car": car, "owner": owner})


func _car_at(pos: Vector2, radius: float, cars: Array, ignore: int) -> int:
	var best := -1
	var best_d := radius
	for j in cars.size():
		if j == ignore or not cars[j].present:
			continue
		var d: float = pos.distance_to(cars[j].position)
		if d < best_d:
			best_d = d
			best = j
	return best


func _outside_road(p: Dictionary) -> bool:
	if path == null:
		return false
	var proj := path.project(p.pos, p.get("hint", -1))
	p["hint"] = proj.index
	return absf(proj.lateral) > road_half_width


## Exact combat state for determinism checks.
func state_snapshot() -> Array:
	var out := [ammo, cooldown, wreck_left, grace_left, destroyed_count, shots_fired]
	for p in projectiles:
		out.append([p.type, p.owner, p.pos, p.dir, p.age])
	for m in mines:
		out.append([m.owner, m.pos, m.age])
	return out
