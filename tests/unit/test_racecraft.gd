extends GutTest
## Rival racecraft: race-length ammunition, personality ammo pacing, Micro
## Nemesis, own racing lines and the personality differences behind them.

var _line: RacingLine


func before_all() -> void:
	var layout: TrackLayout = load("res://src/track/circuit_01.tres")
	_line = RacingLine.new(ClosedPath.new(layout.sample_centerline()), layout.road_width,
		load("res://src/driving/default_driving_params.tres"), load("res://src/ai/default_ai_params.tres"))


func _driver(id: int) -> AiDriver:
	var d := AiDriver.new(_line, load(RivalRoster.params_path(id)))
	d.begin_race(1234)
	return d


func test_ammo_scales_with_race_length() -> void:
	var rules: WeaponRules = load("res://src/combat/default_weapon_rules.tres")
	assert_eq(rules.ammo_scale(3), 1.0)
	assert_eq(rules.ammo_scale(7), 2.0)
	assert_eq(rules.ammo_scale(20), 5.0, "20 laps carry five times the 3-lap rounds")
	assert_eq(rules.ammo_scale(50), 10.0)
	var w := CombatWorld.new(rules, 3)
	var base: int = w.ammo[1][0]
	w.scale_ammo(5.0, [1])
	assert_eq(w.ammo[1][0], base * 5)
	assert_eq(w.start_ammo[1][0], base * 5)
	assert_eq(w.ammo[0][0], base, "only the listed cars")
	w.scale_ammo(50.0, [2])
	assert_eq(w.ammo[2][0], WeaponRules.MAX_ROUNDS, "capped")


func test_disciplined_drivers_save_ammo_when_ahead_of_budget() -> void:
	var ctx := {"lap_count": 20, "laps_left": 15}  # a quarter of the race done
	var victor := _driver(1)
	var rocco := _driver(2)
	# 70 % of the rounds already gone
	assert_gt(victor.spend_penalty(15, 50, ctx), rocco.spend_penalty(15, 50, ctx), "Victor gets pickier than Rocco")
	assert_gt(victor.spend_penalty(15, 50, ctx), 0.3)
	assert_almost_eq(victor.spend_penalty(45, 50, {"lap_count": 20, "laps_left": 15}), 0.0, 0.001, "on budget: no penalty")
	assert_lt(victor.spend_penalty(48, 50, {"lap_count": 20, "laps_left": 5}), 0.0, "well under budget: keener")
	assert_lt(victor.spend_penalty(2, 50, {"lap_count": 20, "laps_left": 1}), 0.0, "last lap: nothing saved")


func test_personality_traits_are_ordered_as_described() -> void:
	var p := {}
	for id in range(1, 10):
		p[id] = load(RivalRoster.params_path(id))
	assert_lt(p[2].ammo_discipline, p[1].ammo_discipline, "Rocco impulsive, Victor calculated")
	assert_lt(p[2].ammo_discipline, p[9].ammo_discipline, "Nina calculated")
	assert_gt(p[1].hazard_lookahead, p[2].hazard_lookahead, "Victor anticipates wrecks, Rocco late")
	assert_lt(p[9].hazard_reaction, p[2].hazard_reaction, "Nina reacts precisely")
	assert_gt(p[8].line_wander, p[1].line_wander, "Finn unpredictable")
	assert_eq(p[7].line_wander, 0.0, "Greta on the line")
	assert_gt(p[2].grudge_bonus, p[1].grudge_bonus, "Rocco holds grudges")


func test_micro_nemesis_favours_the_offender_and_fades() -> void:
	var rocco := _driver(2)
	var t_offender := {"id": 5}
	var t_other := {"id": 6}
	assert_eq(rocco._with_grudge(0.5, t_offender), 0.5, "no grudge yet")
	rocco.on_destroyed_by(5, 2)
	assert_gt(rocco._with_grudge(0.5, t_offender), 0.5, "the offender looks like a better shot")
	assert_eq(rocco._with_grudge(0.5, t_other), 0.5, "nobody else")
	assert_eq(rocco._with_grudge(0.0, t_offender), 0.0, "no chase: only a real chance is improved")
	var early := rocco._with_grudge(0.5, t_offender)
	rocco.grudge_left = rocco.params.grudge_time * 0.25
	assert_lt(rocco._with_grudge(0.5, t_offender), early, "fades")
	rocco.on_destroyed_by(2, 2)
	assert_eq(rocco.grudge_id, 5, "own mine: no grudge against oneself")
	rocco.begin_race(9)
	assert_eq(rocco._with_grudge(0.5, t_offender), 0.5, "a new race forgets")


func test_own_lines_stay_on_the_road_and_differ() -> void:
	var finn := _driver(8)
	var greta := _driver(7)
	var diff := 0.0
	for k in 200:
		finn._time = k * 0.1
		greta._time = k * 0.1
		var s := float(k) * 37.0
		var limit := _line.half_width_at(s)
		assert_true(absf(finn.own_line(s)) <= limit, "inside the road")
		assert_eq(greta.own_line(s), _line.offset_at(s), "Greta drives the shared line")
		diff = maxf(diff, absf(finn.own_line(s) - _line.offset_at(s)))
	assert_gt(diff, 10.0, "Finn wanders off the shared line")
