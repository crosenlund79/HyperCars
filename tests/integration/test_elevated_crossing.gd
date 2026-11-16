extends GutTest
## J1: elevation-aware collisions and progression on the experimental
## figure-eight (exp_figure8_01). Cars on different road levels never touch,
## cars on the same level still do, each level has its own barriers, gates are
## never triggered from the bridge, and all nine rivals complete their laps.

const MAIN_SCENE := preload("res://src/main/main.tscn")
const FIGURE8 := "res://src/track/layouts/exp_figure8_01.tres"

var _main: Node2D


class Coast extends DriverInput:
	## Holds the throttle and steers straight (scripted test driver).
	func drive(_race: Node, _step: float) -> Dictionary:
		return {"steer": 0.0, "fire": true}


func after_each() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8


func _make() -> void:
	_main = MAIN_SCENE.instantiate()
	_main.presentation_enabled = false
	_main.layout_override = load(FIGURE8)
	add_child_autofree(_main)
	await wait_physics_frames(2)


func _crossing() -> Dictionary:
	return TrackLayout.find_crossings(_main.track.centerline)[0]


## Puts racer id on its branch `before` px ahead of arc distance s, moving at speed.
func _place(id: int, s: float, speed: float) -> void:
	var path: ClosedPath = _main.track.path
	var c: Car = _main.cars[id]
	var tan := path.tangent_at(s)
	c.place(Transform2D(tan.angle(), path.point_at(s)))
	c.model.velocity = tan * speed
	_main.progress[id].reset(c.global_position)
	_main.inputs[id] = Coast.new()


func test_cars_on_different_levels_cross_through_each_other() -> void:
	await _make()
	_main.start_race()
	await wait_physics_frames(2)
	var x := _crossing()
	var up := 1
	var down := 2
	_place(up, x.s_a - 140.0, 280.0)
	_place(down, x.s_b - 140.0, 280.0)
	var hits := []
	var walls := []
	for id in [up, down]:
		_main.cars[id].car_hit.connect(func(o: Car, _s: float) -> void: hits.append([id, o.racer_id]))
		_main.cars[id].wall_hit.connect(func(_n: Vector2, _s: float) -> void: walls.append(id))
	var closest := INF
	var layers_at_closest := Vector2i.ZERO
	var start_up: float = _main.progress[up].distance
	var start_down: float = _main.progress[down].distance
	for f in 70:
		await wait_physics_frames(1)
		var d: float = _main.cars[up].global_position.distance_to(_main.cars[down].global_position)
		if d < closest:
			closest = d
			layers_at_closest = Vector2i(_main.cars[up].collision_layer, _main.cars[down].collision_layer)
	assert_lt(closest, 20.0, "the two cars overlapped at the crossing")
	assert_eq(layers_at_closest, Vector2i(Track.CAR_UPPER_LAYER, Track.CAR_LAYER), "upper car on the bridge, lower car underneath")
	assert_eq(hits.filter(func(h: Array) -> bool: return (h[0] == up and h[1] == down) or (h[0] == down and h[1] == up)).size(), 0, "never touched")
	assert_eq(walls.size(), 0, "neither met the other level's barriers")
	assert_gt(_main.progress[up].distance - start_up, 240.0, "upper car carried on along its branch")
	assert_gt(_main.progress[down].distance - start_down, 240.0, "lower car carried on along its branch (no jump to the other branch)")


func test_cars_on_the_same_level_still_collide_on_the_bridge() -> void:
	await _make()
	_main.start_race()
	await wait_physics_frames(2)
	var x := _crossing()
	_place(3, x.s_a - 60.0, 120.0)
	_place(4, x.s_a - 180.0, 400.0)
	var hits := []
	_main.cars[4].car_hit.connect(func(o: Car, _s: float) -> void: hits.append(o.racer_id))
	await wait_physics_frames(60)
	assert_eq(_main.car_levels[3], 1)
	assert_eq(_main.car_levels[4], 1)
	assert_has(hits, 3, "rear-ended on the bridge")


func test_bridge_has_its_own_barriers() -> void:
	await _make()
	_main.start_race()
	await wait_physics_frames(2)
	var x := _crossing()
	var path: ClosedPath = _main.track.path
	var c: Car = _main.cars[5]
	_place(5, x.s_a, 0.0)
	var side := path.tangent_at(x.s_a).orthogonal()
	c.global_rotation = side.angle()
	c.model.heading = side.angle()
	c.model.velocity = side * 300.0  # straight at the bridge railing
	var walls := []
	c.wall_hit.connect(func(_n: Vector2, _s: float) -> void: walls.append(_main.car_levels[5]))
	await wait_physics_frames(40)
	assert_gt(walls.size(), 0, "stopped by the railing")
	assert_eq(walls[0], 1, "an upper-level barrier")
	assert_lt(c.global_position.distance_to(path.point_at(x.s_a)), _main.track.layout.road_width * 0.5 + 5.0, "stayed on the bridge")


func test_all_rivals_complete_their_laps_without_bridge_gate_triggers() -> void:
	await _make()
	_main.set_weapons_enabled(false)
	_main.set_menu_choice(2)  # spectate: the nine rivals
	_main.set_sim_speed(8)
	_main.start_race()
	var from_bridge := []
	_main.track.checkpoint_reached.connect(func(i: int, body: Node2D) -> void:
		if body is Car and _main.car_levels[body.racer_id] != 0:
			from_bridge.append(i))
	var switches := 0
	var last: PackedInt32Array = _main.car_levels.duplicate()
	var t := 0
	while _main.session.state != RaceSession.State.FINISHED and t < 60 * 60 * 6:
		await wait_physics_frames(8)
		t += 8
		for i in last.size():
			if _main.car_levels[i] != last[i]:
				switches += 1
		last = _main.car_levels.duplicate()
	assert_eq(_main.session.state, RaceSession.State.FINISHED)
	for r in _main.session.participants():
		assert_eq(r.tracker.laps_completed, _main.session.lap_count(), "%s finished every lap" % r.display_name)
		assert_gte(r.finish_time, 0.0, "%s finished on track (not classified by the safety net)" % r.display_name)
	assert_eq(from_bridge.size(), 0, "no gate triggered from the bridge")
	assert_gte(switches, 9 * _main.session.lap_count() * 2 - 9, "every car went up and down the bridge each lap")


func test_flat_circuit_never_changes_levels() -> void:
	_main = MAIN_SCENE.instantiate()
	_main.presentation_enabled = false
	add_child_autofree(_main)
	await wait_physics_frames(2)
	assert_false(_main.track.has_node("WallsUpper"))
	_main.start_race()
	await wait_physics_frames(120)
	for i in _main.cars.size():
		assert_eq(_main.car_levels[i], 0)
		assert_eq(_main.level_of(i), 0)
	assert_eq(_main.car.collision_layer, 2)
	assert_eq(_main.car.collision_mask, 3)


func test_prototype_race_is_deterministic() -> void:
	var args := PackedStringArray(["mode=spectate", "ticks=2400", "weapons=0", "layout=exp_figure8_01"])
	var a := ProbeRunner.run(args)
	assert_ne(a, "")
	assert_eq(ProbeRunner.run(args), a, "same result in a fresh process")
