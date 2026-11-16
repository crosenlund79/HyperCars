extends GutTest
## The championship in the full game: three rounds on the schedule's circuits,
## biomes and times, reversed grids between rounds, standings after each round,
## the reward (a real ownership change: the rival then races the junker, the
## player can pick the car), abandoning, and the rival defeat popup.

const GAME_SCENE := preload("res://src/main/game.tscn")
const CARS := "user://test_champ_cars.cfg"

var game: Node


func before_each() -> void:
	CarCollection.new(CARS).clear()
	game = GAME_SCENE.instantiate()
	game.achievements_path = "user://test_champ_ach.cfg"
	game.cars_path = CARS
	add_child_autofree(game)
	await wait_frames(3)


func after_each() -> void:
	Input.action_release(PlayerControls.FIRE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CARS))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_champ_ach.cfg"))


func _tap(action: String) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)
	await wait_physics_frames(1)


func _wait_race() -> void:
	for i in 300:
		if game.race != null and not game._starting:
			return
		await wait_frames(1)


## Drives the player's laps (checkpoints in order) so they win the round.
func _win_round() -> void:
	var race: Node2D = game.race
	race.start_race()
	await wait_physics_frames(5)
	var cps: int = race.track.checkpoint_count()
	for lap in race.session.lap_count():
		for i in range(1, cps):
			race.session.checkpoint_reached(i, 0)
		race.session.checkpoint_reached(0, 0)
	await wait_physics_frames(3)
	assert_eq(race.session.state, RaceSession.State.FINISHED)
	await _tap(PlayerControls.FIRE)
	for i in 120:
		if game.race == null and game.champ_screen.visible:
			break
		await wait_frames(1)


func test_three_rounds_follow_the_schedule_and_reward_the_champion() -> void:
	var schedule: ChampionshipSchedule = game.title.championship
	game.start_championship(0)
	for k in 3:
		await _wait_race()
		var race: Node2D = game.race
		var r := schedule.get_round(k)
		assert_eq(DevLayouts.id_of(race.layout_override), r.layout, "round %d circuit" % (k + 1))
		assert_eq(race.track_variant, r.variant, "round %d biome" % (k + 1))
		assert_eq(race.night, r.night, "round %d time of day" % (k + 1))
		assert_eq(race.session.lap_count(), r.laps)
		assert_eq(race.championship_round, k)
		assert_eq(race.grid_order, game.champ.next_grid(), "the championship's grid")
		if k == 0:
			assert_eq(race.grid_order[-1], 0, "round 1: the player starts last")
		else:
			assert_eq(race.grid_order[-1], 0, "the previous winner (the player) starts last")
		await _win_round()
		assert_true(game.champ_screen.visible, "standings after round %d" % (k + 1))
		assert_eq(game.champ.results.size(), k + 1)
		if k < 2:
			game._next_round()
	assert_true(game.champ.finished())
	assert_eq(game.champ.champion(), 0)
	assert_eq(game.champ.points[0], 75)
	var won: int = game.last_reward
	assert_between(won, 1, 9, "a rival car unlocked")
	assert_true(CarCollection.new(CARS).owns(won), "ownership saved")
	assert_ne(game.title.championship.resource_path, schedule.resource_path, "the next championship differs")
	# the next race: the rival drives the junker; the player can take the car
	game.abandon_championship()
	await wait_frames(60)
	game.title.player_car = won
	game.start_race(0)
	await _wait_race()
	var race: Node2D = game.race
	assert_eq(race.player_car, won)
	assert_eq(race._car_looks[won].body_logical, AssetCatalog.body_of(AssetCatalog.CAR_JUNKER), "the displaced rival races the junker")
	assert_eq(race._car_looks[0].body_logical, AssetCatalog.body_of(AssetCatalog.ai_car(won)), "the player drives the won car")
	assert_eq(race.drivers[won].params.resource_path, RivalRoster.params_path(won), "same personality")
	assert_eq(race.cars[won].model.params, race.cars[0].model.params, "identical performance")
	game.title.player_car = 0
	race.leave_race()
	await wait_frames(40)
	game.start_race(0)
	await _wait_race()
	assert_eq(game.race._car_looks[won].body_logical, AssetCatalog.body_of(AssetCatalog.CAR_JUNKER),
		"still displaced when the player picks another car")


func test_leaving_a_round_abandons_the_championship() -> void:
	game.start_championship(1)
	await _wait_race()
	assert_not_null(game.champ)
	assert_eq(game.race.race_menu._leave.text, "ABANDON CHAMPIONSHIP")
	game.race.leave_race()
	await wait_frames(60)
	assert_null(game.champ)
	assert_null(game.race)
	assert_eq(CarCollection.new(CARS).owned.size(), 0, "nothing won")


func test_a_lost_championship_gives_nothing() -> void:
	game.start_championship(0)
	await _wait_race()
	game.champ.record([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], [])
	game.champ.record([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], [])
	game.race.championship_round_done.emit([1, 2, 3, 4, 5, 6, 7, 8, 9, 0], [0])
	await wait_frames(60)
	assert_true(game.champ.finished())
	assert_eq(game.champ.champion(), 1)
	assert_eq(game.last_reward, -1)
	assert_eq(CarCollection.new(CARS).owned.size(), 0)


func test_reward_texts() -> void:
	assert_string_contains(game.reward_text(9, false), "YOU UNLOCKED THE HUNTER!")
	assert_string_contains(game.reward_text(9, true), "ALL NINE RIVAL CARS COLLECTED")
	assert_string_contains(game.reward_text(-1, true), "collection is complete")


func test_defeat_popup_credits_the_attacker_once() -> void:
	game.start_race(0)
	await _wait_race()
	var race: Node2D = game.race
	race.set_weapons_enabled(true)
	race.start_race()
	await wait_frames(5)
	var popup: DefeatPopup = race.defeat_popup
	var seen: Array = []
	popup.shown.connect(func(rival: int, text: String) -> void: seen.append([rival, text]))
	race.combat.events.append({"kind": "destroyed", "type": 0, "pos": Vector2.ZERO, "car": 0, "owner": 9})
	race.combat.events.append({"kind": "destroyed", "type": 0, "pos": Vector2.ZERO, "car": 0, "owner": 2})
	await wait_frames(3)
	assert_eq(seen.size(), 1, "one card at a time (minimum gap)")
	assert_eq(seen[0][0], 9, "the actual attacker")
	assert_eq(seen[0][1], RivalTaunts.line(9, 0))
	race.combat.events.append({"kind": "destroyed", "type": 0, "pos": Vector2.ZERO, "car": 3, "owner": 9})
	race.combat.events.append({"kind": "destroyed", "type": 0, "pos": Vector2.ZERO, "car": 0, "owner": 0})
	popup.time += DefeatPopup.MIN_GAP
	await wait_frames(3)
	assert_eq(seen.size(), 1, "rivals hitting rivals, or your own mine: no card")
	race.combat.events.append({"kind": "destroyed", "type": 0, "pos": Vector2.ZERO, "car": 0, "owner": 9})
	await wait_frames(3)
	assert_eq(seen.size(), 2)
	assert_eq(seen[1][1], RivalTaunts.line(9, 1), "the next line, not a repeat")
	assert_false(popup.has_node("AudioStreamPlayer"), "silent: the Voice Director stays the only voice")
