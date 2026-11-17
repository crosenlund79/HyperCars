extends GutTest
## Pit lanes and split sections in the race scene: every legal route counts
## laps; a rival really drives into the box, stops and gets +30; a human's
## double tap gives one ticket (feed, HUD, announcer) without K / D; Knockout
## has no service; the limiter holds the car in the lane.

const MAIN_SCENE := preload("res://src/main/main.tscn")
const P := RaceSession.PLAYER_ID

var _main: Node2D


func after_each() -> void:
	Input.action_release(PlayerControls.FIRE)
	Engine.time_scale = 1.0


func _make(layout := "kestrel_ridge", mode := "race", presentation := false) -> void:
	_main = MAIN_SCENE.instantiate()
	_main.presentation_enabled = presentation
	_main.use_command_line_layout = false
	_main.layout_override = load(DevLayouts.LAYOUTS[layout])
	_main.race_mode = mode
	add_child_autofree(_main)
	await wait_physics_frames(2)


## Place the player at arc distance s, in the middle of `lane` there.
func _place_in_lane(s: float, lane: int) -> void:
	var t: Track = _main.track
	var bd := t.layout.route_bounds(s, t.path.length, lane)
	var tan := t.path.tangent_at(s)
	var pos := t.path.point_at(s) + Vector2(-tan.y, tan.x) * (bd.x + bd.y) * 0.5
	_main.car.place(Transform2D(tan.angle(), pos))
	_main.progress[P].reset(pos)  # (a teleport: anchor progress at once, not across the circuit's crossings)


func test_every_route_completes_laps() -> void:
	for lane in 2:  # 0: the racing road and left split lanes; 1: the pit lane and right split lanes
		await _make()
		_main.set_lap_count(1)
		_main.start_race()
		await wait_physics_frames(3)
		var t: Track = _main.track
		for i in range(1, t.checkpoint_count()) + [0]:
			var s: float = t.path.cumulative[t.checkpoint_samples[i]]
			var in_branch := t.layout.branch_at(s, t.path.length) >= 0
			_place_in_lane(s, lane if in_branch else 0)
			await wait_physics_frames(6)
		assert_eq(_main.session.racers[P].tracker.laps_completed, 1, "lane %d: the lap counts (next %d, state %d)" % [lane,
			_main.session.racers[P].tracker.next_checkpoint, _main.session.state])
		_main.queue_free()
		await wait_physics_frames(2)


func test_rival_pit_stop_repairs_thirty_points() -> void:
	await _make()
	_main.set_weapons_enabled(false)
	_main.set_lap_count(4)
	_main.set_menu_choice(2)
	_main.start_race()
	await wait_physics_frames(5)
	_main.damage.condition[1] = 20.0
	await wait_until(func() -> bool: return _main.pits.stops[1] >= 1, 120.0)
	assert_eq(_main.pits.stops[1], 1, "the rival made a pit stop")
	assert_almost_eq(_main.damage.condition[1], 50.0, 0.5, "+30 condition points")
	assert_eq(_main.drivers[1].missed_pits, 0, "it found the pit lane")
	var events: Array = _main.combat.events
	assert_true(events.any(func(e: Dictionary) -> bool: return e.kind == "pit_service" and e.car == 1))


func test_double_tap_override_gives_one_ticket_in_the_feed_without_statistics() -> void:
	await _make("kestrel_ridge", "race", true)
	_main.set_weapons_enabled(false)
	_main.start_race()
	await wait_physics_frames(3)
	var b: Dictionary = _main.track.layout.branches[_main.track.layout.pit_branch()]
	_place_in_lane(float(b.box) - 150.0, 1)
	await wait_physics_frames(10)  # (progress follows a teleport over a few ticks)
	await wait_process_frames(2)
	assert_true(_main.pits.limiter_on(P), "the limiter engaged in the pit lane")
	assert_string_contains(_main.hud.pit_text(), "PIT LIMITER")
	assert_string_contains(_main.hud.pit_text(), PlayerControls.key_text(PlayerControls.FIRE), "the configured accelerator")
	for k in 2:
		Input.action_press(PlayerControls.FIRE)
		await wait_physics_frames(3)
		Input.action_release(PlayerControls.FIRE)
		await wait_physics_frames(3)
	assert_eq(_main.pits.tickets[P], 1, "one ticket")
	assert_false(_main.pits.limiter_on(P), "limiter overridden")
	assert_eq(_main.car.model.speed_cap, INF, "full speed rules again")
	var tickets: Array = _main.combat.events.filter(func(e: Dictionary) -> bool: return e.kind == "ticket")
	assert_eq(tickets.size(), 1, "one ticket event")
	await wait_process_frames(3)
	assert_true(_main.kill_feed.lines().has("YOU [ticket] PIT SPEEDING"), str(_main.kill_feed.lines()))
	assert_eq(_main.stats.line(P), [0, 0, 0], "no kills, deaths or tombstones")
	for k in 3:  # more taps in the same traversal: nothing more
		Input.action_press(PlayerControls.FIRE)
		await wait_physics_frames(2)
		Input.action_release(PlayerControls.FIRE)
		await wait_physics_frames(2)
	assert_eq(_main.pits.tickets[P], 1, "never charged twice")


func test_held_accelerator_through_the_entry_never_overrides() -> void:
	await _make()
	_main.set_weapons_enabled(false)
	_main.start_race()
	await wait_physics_frames(3)
	var b: Dictionary = _main.track.layout.branches[_main.track.layout.pit_branch()]
	var lane_start: float = float(b.from) + float(b.ramp) - 40.0  # the pit lane is formed; the limiter starts at the divider
	Input.action_press(PlayerControls.FIRE)  # floored from before the lane begins
	_place_in_lane(lane_start, 1)
	_main.car.model.velocity = Vector2.from_angle(_main.car.model.heading) * _main.driving_params.max_speed
	await wait_until(func() -> bool: return _main.pits.in_lane[P] == 1, 10.0)
	await wait_physics_frames(50)
	assert_eq(_main.pits.in_lane[P], 1, "still in the pit lane")
	assert_eq(_main.pits.tickets[P], 0, "holding Fire into the lane is not a double tap")
	assert_lt(_main.car.model.velocity.length(), _main.driving_params.max_speed * 0.5 + 1.0, "held at the limiter")


func test_knockout_has_no_pit_service() -> void:
	await _make("kestrel_ridge", "knockout")
	_main.set_lap_count(9)
	_main.start_race()
	await wait_physics_frames(3)
	assert_false(_main.pits.service_enabled)
