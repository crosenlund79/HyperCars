extends GutTest
## Biomes change handling a little and identically for every car; night only
## changes the look; weather is presentation; race-length ammunition in the
## race scene; wreck pass-through only for wrecked cars.

const MAIN_SCENE := preload("res://src/main/main.tscn")


func _race(variant: int, night: bool = false, presentation: bool = false, laps: int = 3) -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate()
	main.track_variant = variant
	main.night = night
	main.presentation_enabled = presentation
	main.use_command_line_layout = false
	main.layout_override = load(DevLayouts.LAYOUTS["kestrel_ridge"])
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.set_lap_count(laps)
	main.set_weapons_enabled(true)
	return main


func test_biome_handling() -> void:
	var base: DrivingParams = load("res://src/driving/default_driving_params.tres")
	var green: Node2D = await _race(1)
	assert_eq(green.driving_params.grip, base.grip, "Green Valley is the baseline")
	var winter: Node2D = await _race(3)
	assert_lt(winter.driving_params.grip, base.grip * 0.8, "Winter: lower grip")
	assert_lt(winter.driving_params.brake_deceleration, base.brake_deceleration, "longer braking")
	var waste: Node2D = await _race(2)
	assert_lt(waste.driving_params.grip, base.grip)
	assert_gt(waste.driving_params.grip, winter.driving_params.grip, "Wasteland is subtler than Winter")
	for c in winter.cars:
		assert_eq(c.model.params, winter.driving_params, "identical physics for every car")


func test_night_never_changes_physics() -> void:
	var day: Node2D = await _race(3, false)
	var night: Node2D = await _race(3, true)
	for prop in ["grip", "acceleration", "turn_rate_degrees", "brake_deceleration", "max_speed"]:
		assert_eq(night.driving_params.get(prop), day.driving_params.get(prop), prop)


func test_night_lighting_and_weather_presentation() -> void:
	var main: Node2D = await _race(3, true, true)
	assert_true(main.lighting.enabled, "night lights on from the start")
	assert_not_null(main.get_node_or_null("Weather"), "snowfall")
	var day: Node2D = await _race(1, false, true)
	assert_false(day.lighting.enabled)
	assert_null(day.get_node_or_null("Weather"), "no weather in Green Valley")


func test_long_races_carry_more_ammunition() -> void:
	var short: Node2D = await _race(1, false, false, 3)
	var long: Node2D = await _race(1, false, false, 20)
	short.start_race()
	long.start_race()
	await wait_physics_frames(2)
	for id in range(1, 10):
		assert_eq(long.combat.start_ammo[id][0], mini(WeaponRules.MAX_ROUNDS, short.combat.start_ammo[id][0] * 5), "rival %d" % id)
	assert_eq(long.combat.start_ammo[0][0], short.combat.start_ammo[0][0] * 5, "the player too")


func test_wreck_pass_through_only_for_wrecked_cars() -> void:
	var main: Node2D = await _race(1)
	main.start_race()
	await wait_physics_frames(2)
	var a: Car = main.cars[3]
	var b: Car = main.cars[4]
	b.global_position = a.global_position + Vector2(40, 0)
	for i in 60:
		main._update_wreck_passes(Car.FIXED_STEP)
	assert_false(a.get_collision_exceptions().has(b), "two active cars always collide")
	main.combat.wreck_left[4] = 3.0  # b is wrecked
	assert_true(main.combat.is_wrecked(4))
	a.model.velocity = Vector2.ZERO
	for i in 20:
		main._update_wreck_passes(Car.FIXED_STEP)
	assert_false(a.get_collision_exceptions().has(b), "not before 0.5 s")
	for i in 20:
		main._update_wreck_passes(Car.FIXED_STEP)
	assert_true(a.get_collision_exceptions().has(b), "held up for 0.5 s: through that wreck")
	assert_false(a.get_collision_exceptions().has(main.cars[5]), "only that one")
	main.combat.wreck_left[4] = 0.0
	b.global_position = a.global_position + Vector2(200, 0)
	main._update_wreck_passes(Car.FIXED_STEP)
	assert_false(a.get_collision_exceptions().has(b), "restored once the wreck is back and apart")
