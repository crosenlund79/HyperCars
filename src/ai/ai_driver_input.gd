class_name AiDriverInput
extends DriverInput
## A computer driver: builds the AiDriver's view of the race exactly as before
## and returns its decisions as a command. AiDriver and its personalities are
## unchanged.

var driver: AiDriver


func _init(p_racer_id: int, p_driver: AiDriver) -> void:
	racer_id = p_racer_id
	driver = p_driver


func begin_race(seed_value: int) -> void:
	driver.begin_race(seed_value)


func on_destroyed() -> void:
	driver.on_destroyed()


func drive(race: Node, step: float) -> Dictionary:
	var id := racer_id
	var cars: Array[Car] = race.cars
	var progress: Array[RaceProgress] = race.progress
	var others: Array = []
	for other in race.grid_order:
		if other != id:
			others.append({"distance": progress[other].distance, "lateral": progress[other].lateral,
				"speed": cars[other].model.forward_speed()})
	var me := {"position": cars[id].global_position, "heading": cars[id].model.heading,
		"speed": cars[id].model.forward_speed(), "distance": progress[id].distance,
		"lateral": progress[id].lateral}
	return driver.decide(me, others, step)


func weapons(race: Node, step: float, _states: Array) -> Dictionary:
	var id := racer_id
	var out := {"front": false, "rear": false}
	var combat: CombatWorld = race.combat
	var session: RaceSession = race.session
	if combat.is_wrecked(id) or session.racers[id].is_finished():
		return out
	var front_ready := combat.can_fire(id, CombatWorld.FRONT)
	var rear_ready := combat.can_fire(id, CombatWorld.REAR)
	if not front_ready and not rear_ready:
		return out
	var cars: Array[Car] = race.cars
	var progress: Array[RaceProgress] = race.progress
	var rules: WeaponRules = race.weapon_rules
	var d := driver
	var targets: Array = []
	for other in race.grid_order:
		if other == id:
			continue
		targets.append({"position": cars[other].global_position, "velocity": cars[other].model.velocity,
			"distance": progress[other].distance, "lateral": progress[other].lateral,
			"speed": cars[other].model.forward_speed(), "wrecked": combat.is_wrecked(other)})
	var me := {"position": cars[id].global_position, "heading": cars[id].model.heading,
		"speed": cars[id].model.forward_speed(), "distance": progress[id].distance, "lateral": progress[id].lateral}
	var r := session.racers[id]
	var ctx := {"front_ready": front_ready, "rear_ready": rear_ready, "front_ammo": combat.ammo[id][CombatWorld.FRONT],
		"front_start": combat.start_ammo[id][CombatWorld.FRONT], "laps_left": r.tracker.lap_count - r.tracker.laps_completed,
		"lap_count": r.tracker.lap_count, "missile_speed": rules.missile_speed, "hit_radius": rules.hit_radius,
		"mine_fuse": rules.mine_fuse,
		"pressure": d.params.pressure_attack_drop > 0.0 and d.under_pressure(me, targets)}
	if race.combat_style == WeaponRules.Style.TACTICAL:
		ctx.merge({"front_weapon": combat.weapon_of(id, CombatWorld.FRONT), "rear_weapon": combat.weapon_of(id, CombatWorld.REAR),
			"rear_ammo": combat.ammo[id][CombatWorld.REAR], "rear_start": combat.start_ammo[id][CombatWorld.REAR],
			"homing_range": rules.homing_range, "super_orbit_radius": rules.super_orbit_radius})
		return d.decide_weapons_tactical(me, targets, ctx, step)
	return d.decide_weapons(me, targets, ctx, step)
