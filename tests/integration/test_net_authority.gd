extends GutTest
## M5.1: host authority in one process — the client race scene lives in its own
## SubViewport (own physics world) and never simulates: its cars stay inactive,
## its checkpoints are ignored, it cannot start a race; the host starts only
## when the client is ready; the client mirrors grid, state and positions.

const MAIN_SCENE := preload("res://src/main/main.tscn")

var host_link: NetLink
var client_link: NetLink
var host: Node2D
var client: Node2D


func before_each() -> void:
	host_link = NetLink.new()
	client_link = NetLink.new()
	add_child_autofree(host_link)
	add_child_autofree(client_link)
	host_link.host(24721)
	client_link.join("127.0.0.1", 24721)
	await wait_until(func() -> bool: return host_link.peers().size() == 1 and client_link.peers().size() == 1, 5.0)
	host = _make(NetRace.Role.HOST, self)
	var vp := SubViewport.new()
	add_child_autofree(vp)
	client = _make(NetRace.Role.CLIENT, vp)
	await wait_physics_frames(10)


func after_each() -> void:
	host_link.close()
	client_link.close()
	for a in [PlayerControls.FIRE, PlayerControls.FIRE_FRONT]:
		Input.action_release(a)


func _make(role: NetRace.Role, parent: Node) -> Node2D:
	var m: Node2D = MAIN_SCENE.instantiate()
	m.presentation_enabled = false
	m.human_count = 2
	m.net = NetRace.new(host_link if role == NetRace.Role.HOST else client_link, role)
	parent.add_child(m)
	if parent == self:
		autofree(m)
	return m


func test_roles_cameras_and_inputs() -> void:
	assert_eq(host.local_player_id, RaceSession.PLAYER_ID)
	assert_eq(client.local_player_id, RaceSession.PLAYER_2_ID)
	assert_null(host.player_views, "no split screen in network races")
	assert_eq(client.camera.target, client.cars[RaceSession.PLAYER_2_ID], "each computer follows its own car")
	assert_true(host.inputs[RaceSession.PLAYER_2_ID] is RemoteDriverInput)
	assert_null(host.garage)
	assert_null(host.achievements)


func test_host_waits_for_the_client_then_both_race() -> void:
	Input.action_press(PlayerControls.FIRE)
	await wait_physics_frames(3)
	Input.action_release(PlayerControls.FIRE)
	assert_eq(host.session.state, RaceSession.State.MODE_SELECT, "client not ready yet")
	client.net.local_ready = true
	client.net._send_ready()
	await wait_until(func() -> bool: return host.net.client_ready, 3.0)
	host.start_race()
	await wait_until(func() -> bool: return client.session.state == RaceSession.State.RACING, 3.0)
	assert_eq(client.grid_order, host.grid_order)
	assert_eq(client.session.sitting_out, host.session.sitting_out)
	await wait_physics_frames(120)
	for c in client.cars:
		assert_false(c.active, "client never simulates")
	var drift := 0.0
	for id in host.grid_order:
		drift = maxf(drift, client.cars[id].global_position.distance_to(host.cars[id].global_position))
	assert_lt(drift, 80.0, "client shows the host's cars (a few ticks behind)")
	client.session.checkpoint_reached(1, 3)
	client._on_checkpoint_reached(1, client.cars[3])
	await wait_physics_frames(6)
	assert_eq(client.session.racers[3].tracker.next_checkpoint, host.session.racers[3].tracker.next_checkpoint,
		"laps come from the host")


func test_client_input_drives_only_the_clients_car_on_the_host() -> void:
	client.net.local_ready = true
	client.net._send_ready()
	await wait_until(func() -> bool: return host.net.client_ready, 3.0)
	host.start_race()
	await wait_until(func() -> bool: return client.session.state == RaceSession.State.RACING, 3.0)
	client.net.input_source = func() -> Dictionary: return {"steer": 0.0, "fire": true}
	await wait_physics_frames(60)
	assert_gt(host.cars[RaceSession.PLAYER_2_ID].model.forward_speed(), 50.0, "P2 accelerates on the host")
	assert_lt(host.cars[RaceSession.PLAYER_ID].model.forward_speed(), 5.0, "P1 untouched")


func test_client_cannot_start_and_repeated_fire_does_not_restart() -> void:
	client.net.local_ready = true
	client.net._send_ready()
	await wait_until(func() -> bool: return host.net.client_ready, 3.0)
	host.start_race()
	await wait_until(func() -> bool: return client.session.state == RaceSession.State.RACING, 3.0)
	var started: int = host.races_started
	for k in 5:
		Input.action_press(PlayerControls.FIRE)
		await wait_physics_frames(4)
		Input.action_release(PlayerControls.FIRE)
		await wait_physics_frames(4)
	assert_eq(host.races_started, started, "no restart")
	assert_eq(host.session.state, RaceSession.State.RACING)
	assert_eq(client.session.state, RaceSession.State.RACING)
