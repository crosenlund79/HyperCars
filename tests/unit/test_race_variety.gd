extends GutTest
## Race variety: each new race scene gets its own AI seed from the session
## seed; a given --seed=N reproduces a whole session; race scenes built
## directly (tests, probes) keep the fixed default seed.

const GAME_SCENE := preload("res://src/main/game.tscn")


func test_seed_from_arguments() -> void:
	assert_eq(GameSeed.from_args(PackedStringArray(["--seed=42"])), 42)
	assert_eq(GameSeed.from_args(PackedStringArray(["--layout=ravenhook", "--seed=7"])), 7)
	var a := GameSeed.from_args(PackedStringArray())
	var b := GameSeed.from_args(PackedStringArray())
	assert_ne(a, b, "random sessions differ")


func _race_seeds(session: int) -> Array:
	var game := GAME_SCENE.instantiate()
	game.session_seed = session
	add_child_autofree(game)
	await wait_physics_frames(2)
	var seeds := []
	for k in 2:
		game.start_race(0)
		for i in 300:
			if game.race != null and not game._starting:
				break
			await wait_process_frames(1)
		seeds.append(game.race.base_seed)
		game.back_to_title()
		for i in 300:
			if game.race == null and not game._starting:
				break
			await wait_process_frames(1)
	game.title.stop_audio()
	return seeds


func test_new_races_get_new_seeds_and_a_session_seed_reproduces_them() -> void:
	var one: Array = await _race_seeds(1234)
	assert_ne(one[0], one[1], "the next race differs from the last")
	assert_ne(one[0], 1991, "not the fixed default")
	var again: Array = await _race_seeds(1234)
	assert_eq(again, one, "same session seed, same races")
	var other: Array = await _race_seeds(99)
	assert_ne(other, one, "another session, other races")


func test_race_scene_keeps_its_fixed_default() -> void:
	var main: Node2D = load("res://src/main/main.tscn").instantiate()
	assert_eq(main.base_seed, 1991, "tests and probes stay deterministic")
	main.free()
