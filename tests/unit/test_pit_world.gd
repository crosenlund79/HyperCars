extends GutTest
## Pit lanes, pure rules: the limiter (50 % cap, smooth slow-down, normal speed
## after the lane), the double-tap override (held accelerator never counts),
## one ticket per traversal, fines vs the sporting penalty, service (stationary
## in the box, full duration, +30 capped at 100, interrupted, once per
## traversal, never after a DNF) and the branch geometry.

const DT := 1.0 / 60.0

var _rules: PitRules


func before_each() -> void:
	_rules = load("res://src/race/default_pit_rules.tres")


func _layout() -> TrackLayout:
	return load(DevLayouts.LAYOUTS["kestrel_ridge"])


func test_limiter_caps_at_half_with_controlled_slowdown() -> void:
	var params: DrivingParams = load("res://src/driving/default_driving_params.tres")
	var m := CarModel.new(params)
	m.velocity = Vector2(params.max_speed, 0)
	m.speed_cap = params.max_speed * _rules.limiter_share
	m.update(DT, 0.0, true)
	assert_gt(m.forward_speed(), params.max_speed * 0.9, "no instant drop: a smooth slow-down")
	for i in 120:
		m.update(DT, 0.0, true)
	assert_almost_eq(m.forward_speed(), params.max_speed * 0.5, 0.5, "held at 50 % of top speed")
	m.speed_cap = INF
	m.update(DT, 0.0, true)
	assert_almost_eq(m.forward_speed(), params.max_speed * 0.5 + params.acceleration * DT, 0.01,
		"after the lane: normal acceleration (no boost to top speed)")


func test_limiter_on_in_the_lane_off_outside() -> void:
	var p := PitWorld.new(_rules, 3)
	assert_false(p.limiter_on(0))
	p.step(0, true, false, 200.0, 50.0, 100.0, false, DT)
	assert_true(p.limiter_on(0), "on entering the pit lane")
	assert_true(p.limited(0))
	p.step(0, false, false, 200.0, 50.0, 100.0, false, DT)
	assert_false(p.limited(0), "off when leaving it")


func test_override_once_per_traversal_with_one_ticket() -> void:
	var p := PitWorld.new(_rules, 2)
	assert_false(p.request_override(0), "outside the pit lane: nothing to override")
	p.step(0, true, false, 200.0, 50.0, 100.0, false, DT)
	assert_true(p.request_override(0), "granted")
	assert_false(p.limiter_on(0), "limiter off for this traversal")
	assert_false(p.request_override(0), "a second request changes nothing")
	assert_eq(p.tickets[0], 1, "one ticket per traversal")
	p.step(0, true, false, 400.0, 50.0, 100.0, false, DT)
	assert_false(p.limiter_on(0), "stays off for the rest of the lane")
	p.step(0, false, false, 400.0, 50.0, 100.0, false, DT)
	assert_true(p.limited(0), "rivals / non-money modes: the penalty after the lane")
	for i in int(_rules.penalty_time / DT) + 2:
		p.step(0, false, false, 200.0, 50.0, 100.0, false, DT)
	assert_false(p.limited(0), "penalty served")
	p.step(0, true, false, 200.0, 50.0, 100.0, false, DT)
	assert_true(p.limiter_on(0), "the next entry: the limiter engages again")
	assert_true(p.request_override(0))
	assert_eq(p.tickets[0], 2, "a new traversal, a new ticket")


func test_garage_human_pays_a_fine_instead_of_the_penalty() -> void:
	var p := PitWorld.new(_rules, 2)
	p.pays_fines[0] = 1
	p.step(0, true, false, 200.0, 50.0, 100.0, false, DT)
	p.request_override(0)
	p.request_override(0)
	assert_eq(p.fines[0], _rules.fine, "fined once")
	p.step(0, false, false, 400.0, 50.0, 100.0, false, DT)
	assert_false(p.limited(0), "no penalty on top of the fine")
	var g := PlayerGarage.new(load("res://src/garage/default_garage_rules.tres"))
	g.money = 100
	g.begin_race()
	g.settle_race(8, 0, 0, -1.0, 3, p.fines[0])
	assert_eq(g.money, 0, "deducted from the balance, never below $0 (no debt)")
	assert_eq(g.last_fine, _rules.fine)


func test_service_rules() -> void:
	var p := PitWorld.new(_rules, 2)
	p.step(0, true, false, 100.0, 42.0, 100.0, false, DT)
	var got := 0.0
	var ticks := 0
	while got == 0.0 and ticks < 2000:
		got = p.step(0, true, true, 0.0, 42.0, 100.0, false, DT)
		ticks += 1
	assert_almost_eq(ticks * DT, _rules.service_time, 2.0 * DT, "the full service time, stationary in the box")
	assert_eq(got, 30.0, "+30 condition points")
	for i in 600:
		assert_eq(p.step(0, true, true, 0.0, 72.0, 100.0, false, DT), 0.0, "once per traversal")
	# interrupted service: no repair
	var q := PitWorld.new(_rules, 1)
	q.step(0, true, true, 0.0, 50.0, 100.0, false, DT)
	for i in int(_rules.service_time / DT * 0.8):
		q.step(0, true, true, 0.0, 50.0, 100.0, false, DT)
	q.step(0, true, true, 60.0, 50.0, 100.0, false, DT)  # drove off early
	assert_eq(q.service[0], 0.0, "service interrupted")
	assert_eq(q.stops[0], 0)
	# moving is not stationary; capped at 100
	var r := PitWorld.new(_rules, 1)
	r.step(0, true, true, 0.0, 90.0, 100.0, false, DT)
	var add := 0.0
	for i in int(_rules.service_time / DT) + 5:
		add = maxf(add, r.step(0, true, true, 0.0, 90.0, 100.0, false, DT))
	assert_eq(add, 10.0, "never above 100 %")
	# a DNF car is never repaired
	var x := PitWorld.new(_rules, 1)
	for i in int(_rules.service_time / DT) + 5:
		assert_eq(x.step(0, true, true, 0.0, 0.0, 100.0, true, DT), 0.0)
	# service disabled (Knockout)
	var k := PitWorld.new(_rules, 1)
	k.service_enabled = false
	for i in int(_rules.service_time / DT) + 5:
		assert_eq(k.step(0, true, true, 0.0, 40.0, 100.0, false, DT), 0.0)


func test_two_legitimate_stops_need_two_traversals() -> void:
	var p := PitWorld.new(_rules, 1)
	var cond := 20.0
	for lap in 2:
		p.step(0, true, false, 100.0, cond, 100.0, false, DT)
		for i in int(_rules.service_time / DT) + 5:
			cond += p.step(0, true, true, 0.0, cond, 100.0, false, DT)
		# nudge out of the box and back in: no second service
		p.step(0, true, false, 20.0, cond, 100.0, false, DT)
		for i in int(_rules.service_time / DT) + 5:
			cond += p.step(0, true, true, 0.0, cond, 100.0, false, DT)
		p.step(0, false, false, 200.0, cond, 100.0, false, DT)  # out of the lane, a lap later back
	assert_eq(cond, 80.0, "two stops, +30 each")
	assert_eq(p.stops[0], 2)


func test_double_tap_detection() -> void:
	var d := PitTapDetector.new()
	var fired := false
	# held accelerator through the entry: never an override, however long
	for i in 120:
		fired = fired or d.step(true, i > 10, DT, _rules.double_tap_window)
	assert_false(fired, "holding the accelerator never overrides")
	# release, then two quick presses
	fired = d.step(false, true, DT, _rules.double_tap_window)
	var taps := [true, true, false, false, true]  # press (held 2 ticks), release, press
	for t in taps:
		fired = fired or d.step(t, true, DT, _rules.double_tap_window)
	assert_true(fired, "two separate presses within the window")
	# two slow presses do not count
	var e := PitTapDetector.new()
	var f := false
	e.step(false, true, DT, _rules.double_tap_window)
	f = e.step(true, true, DT, _rules.double_tap_window)
	for i in 40:
		f = f or e.step(false, true, DT, _rules.double_tap_window)
	f = f or e.step(true, true, DT, _rules.double_tap_window)
	assert_false(f, "too slow: not a double tap")
	# outside the pit lane nothing counts
	var o := PitTapDetector.new()
	var g := false
	for t in [false, true, false, true, false, true]:
		g = g or o.step(t, false, DT, _rules.double_tap_window)
	assert_false(g)


func test_limiter_never_applies_on_the_racing_road() -> void:
	for id in DevLayouts.PLAYER_LAYOUTS:
		var l: TrackLayout = DevLayouts.load_layout(id)
		var path := ClosedPath.new(l.sample_centerline())
		var s := 0.0
		while s < path.length:
			var main := l.route_bounds(s, path.length, 0)
			for lat in [main.x + 2.0, 0.0, main.y - 2.0]:
				assert_false(l.in_pit_lane(s, path.length, lat), "%s at %.0f / %.0f" % [id, s, lat])
			s += 20.0


func test_divider_stops_missiles_and_lanes_are_drivable() -> void:
	var l := _layout()
	var path := ClosedPath.new(l.sample_centerline())
	for k in l.branches.size():
		var b: Dictionary = l.branches[k]
		var mid: float = (float(b.from) + float(b.to)) * 0.5
		var d := l.divider_at(mid, path.length)
		assert_ne(d, Vector2.INF, "branch %d has a divider mid-way" % k)
		assert_true(l.road_blocked(mid, path.length, (d.x + d.y) * 0.5), "the divider is solid")
		for lane in 2:
			var bd := l.route_bounds(mid, path.length, lane)
			assert_false(l.road_blocked(mid, path.length, (bd.x + bd.y) * 0.5), "lane %d is open road" % lane)
			assert_gt(bd.y - bd.x, 60.0, "lane %d fits a car" % lane)
