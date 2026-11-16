extends GutTest
## Championship rules (points, DNF, ties, grids, schedules) and the car
## collection (unlocks, persistence, no duplicates, completion).

const CUP := preload("res://src/championship/hypercars_cup.tres")
const PATH := "user://test_car_collection.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _order(first: Array) -> Array:
	var out := first.duplicate()
	for id in range(0, 10):
		if not out.has(id):
			out.append(id)
	return out


func test_points_accumulate_by_position() -> void:
	var c := Championship.new(CUP)
	c.record(_order([3, 0, 5]), [])
	assert_eq(c.points[3], 25)
	assert_eq(c.points[0], 18)
	assert_eq(c.points[5], 15)
	c.record(_order([0, 3]), [])
	assert_eq(c.points[0], 43)
	assert_eq(c.points[3], 43)
	assert_eq(c.standings()[0], 0, "tied on points, one win and one second each: the last round decides")


func test_dnf_scores_nothing_and_ranks_last_in_round() -> void:
	var c := Championship.new(CUP)
	var order := _order([1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
	c.record(order, [0])
	assert_eq(c.points[0], 0, "a DNF scores nothing even in a points position")
	assert_eq(c.position_in(0, 0), 0)
	c.record(_order([2, 1]), [9])
	assert_eq(c.points[9], 2, "the first round's 9th place only")


func test_countback_breaks_ties() -> void:
	var c := Championship.new(CUP)
	c.record(_order([7, 8]), [])                          # 7: 25, 8: 18
	c.record(_order([8, 9, 1, 2, 3, 4, 5, 6, 0, 7]), [7])  # 8: 43, 7 retired
	c.points[7] = 43  # force a points tie
	assert_eq(c.standings()[0], 8, "equal points and one win each: 8 also has a second place")
	var ids := c.standings()
	for k in ids.size() - 1:
		assert_true(c.points[ids[k]] >= c.points[ids[k + 1]], "sorted by points")


func test_grids_reverse_the_last_result() -> void:
	var c := Championship.new(CUP)
	assert_eq(c.next_grid(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 0] as Array[int], "round 1: player last")
	var order := _order([5, 0, 2])
	c.record(order, [])
	var grid := c.next_grid()
	assert_eq(grid[-1], 5, "the winner starts last")
	assert_eq(grid[0], order[-1])


func test_finishes_after_three_rounds() -> void:
	var c := Championship.new(CUP)
	for k in 3:
		assert_false(c.finished())
		assert_eq(c.next_round().layout, CUP.layouts[k])
		c.record(_order([0]), [])
	assert_true(c.finished())
	assert_eq(c.champion(), 0)
	c.record(_order([1]), [])
	assert_eq(c.results.size(), 3, "no fourth round")


func test_schedules_rotate_and_cover_all_circuits() -> void:
	var a := ChampionshipSchedule.for_run(0)
	var b := ChampionshipSchedule.for_run(1)
	assert_ne(a.resource_path, b.resource_path, "the next championship races other combinations")
	assert_eq(ChampionshipSchedule.for_run(2).resource_path, a.resource_path)
	for s: ChampionshipSchedule in [a, b]:
		assert_eq(s.round_count(), 3)
		var seen := {}
		for i in 3:
			var r: Dictionary = s.get_round(i)
			seen[r.layout] = true
			assert_true(DevLayouts.PLAYER_LAYOUTS.has(r.layout))
			assert_true(r.variant >= 1 and r.variant <= 3)
		assert_eq(seen.size(), 3, "one round on each original circuit")
	var nights := 0
	for i in 3:
		if a.get_round(i).night:
			nights += 1
	assert_true(nights > 0 and nights < 3, "day and night rounds")


func test_collection_unlocks_each_rival_once_and_persists() -> void:
	var cars := CarCollection.new(PATH)
	cars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := {}
	for k in 9:
		var id := cars.unlock_random(rng)
		assert_true(id >= 1 and id <= 9)
		assert_false(got.has(id), "never a duplicate")
		got[id] = true
	assert_true(cars.all_owned())
	assert_eq(cars.unlock_random(rng), -1, "nothing left to win")
	var again := CarCollection.new(PATH)
	assert_eq(again.owned.size(), 9, "saved between sessions")
	assert_true(again.displaced(4))
	assert_eq(again.choices().size(), 10)
	assert_eq(again.choices()[0], CarCollection.OWN_CAR)


func test_collection_counts_championships() -> void:
	var cars := CarCollection.new(PATH)
	cars.clear()
	cars.count_championship()
	cars.count_championship()
	assert_eq(CarCollection.new(PATH).championships_run, 2)


func test_repaint_turns_the_main_paint_red_and_keeps_the_shape() -> void:
	# a painted car: blue paint, a grey window, a dark outline (the headless
	# test renderer keeps no images of imported textures)
	var img := Image.create(40, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(2, 2, 36, 16), Color(0.15, 0.12, 0.1))
	img.fill_rect(Rect2i(4, 4, 32, 12), Color(0.2, 0.45, 0.85))
	img.fill_rect(Rect2i(16, 6, 8, 8), Color(0.6, 0.62, 0.64))
	var a := img
	var b := CarPaint.repaint_image(img)
	assert_eq(b.get_size(), a.get_size())
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			assert_eq(b.get_pixel(x, y).a, a.get_pixel(x, y).a)
			if not b.get_pixel(x, y).is_equal_approx(a.get_pixel(x, y)):
				changed += 1
	assert_eq(changed, 32 * 12 - 64, "the paint changed, the window did not")
	assert_almost_eq(CarPaint.dominant_hue(b), CarPaint.PLAYER_HUE, 0.04, "now red")


func test_repaint_falls_back_for_unreadable_art() -> void:
	assert_null(CarPaint.repaint_image(Image.create(8, 8, false, Image.FORMAT_RGBA8)), "no paint colour")
	var blank := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	assert_eq(CarPaint.repaint(blank), blank, "the picture as it is")
	assert_null(CarPaint.repaint(null))


func test_every_rival_has_taunts() -> void:
	for id in range(1, 10):
		assert_eq(RivalTaunts.count(id), 3)
		assert_ne(RivalTaunts.line(id, 0), RivalTaunts.line(id, 1))
