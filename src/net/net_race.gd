class_name NetRace
extends Node
## Network side of one race scene (M5.1, host-authoritative, LAN).
## HOST: runs the normal race; the client's driver is a RemoteDriverInput fed
## by INPUT messages; sends SETUP (grid and settings), START, a SNAP every
## SNAP_INTERVAL ticks and RESULTS. CLIENT: never simulates the race; it sends
## its player's commands every tick, readies up on the grid, and shows the
## host's snapshots, interpolating car movement. Lives as a child of the race
## scene; the NetLink (connection) is owned by whoever created the session.

enum Role { HOST, CLIENT }
## Message types ([type, ...] arrays over NetLink).
enum Msg { WELCOME, HELLO, SETUP, READY, START, SNAP, INPUT, RESULTS, EVENTS, BYE, REJECT }

const PROTOCOL := 1
const SNAP_INTERVAL := 2
## Client renders this many ticks behind the newest snapshot (smoothness vs delay).
const INTERP_DELAY := 4.0
const BUFFER := 24

var link: NetLink
var role: Role
var race: Node
var peer_id := 0
## HOST: the client's driver and readiness.
var remote_input: RemoteDriverInput
var client_ready := false
var client_mode: CarModel.ControlMode = CarModel.ControlMode.FIRE_TO_ACCELERATE
## CLIENT: own readiness, press totals, snapshot buffer and render clock.
var local_ready := false
var front_total := 0
var rear_total := 0
var input_tick := 0
var snapshots: Array = []
var render_tick := -1.0
## CLIENT: optional source of the local player's command (tests use an autopilot);
## default reads the single-player actions on this computer.
var input_source: Callable
var _tick := 0
## HOST: combat events already sent for the current race.
var _sent_events := 0
var _events_race := -1


func _init(p_link: NetLink, p_role: Role) -> void:
	link = p_link
	role = p_role
	name = "NetRace"
	if role == Role.HOST:
		remote_input = RemoteDriverInput.new(RaceSession.PLAYER_2_ID)


func is_host() -> bool:
	return role == Role.HOST


func is_client() -> bool:
	return role == Role.CLIENT


## Called by the race scene once its cars and session exist.
func attach(p_race: Node) -> void:
	race = p_race
	link.message.connect(_on_message)
	link.peer_left.connect(_on_peer_left)
	link.server_closed.connect(_on_server_closed)
	if is_client():
		link.send([Msg.HELLO, PROTOCOL], true)
	else:
		var p := link.peers()
		peer_id = p[0] if p.size() > 0 else 0
		send_setup()
	race._show_menu()


func _exit_tree() -> void:
	if link != null and link.message.is_connected(_on_message):
		link.message.disconnect(_on_message)
	if link != null and link.peer_left.is_connected(_on_peer_left):
		link.peer_left.disconnect(_on_peer_left)
		link.server_closed.disconnect(_on_server_closed)


## The other computer is gone: the race ends gracefully (no AI takeover).
func _on_peer_left(_peer: int) -> void:
	if race != null:
		race.on_network_lost("The other player left the game.")


func _on_server_closed() -> void:
	if race != null:
		race.on_network_lost("The host left the game.")


# ------------------------------------------------------------------ host side

## Current grid and settings, sent whenever they change (reliable).
func send_setup() -> void:
	if not is_host() or race == null or race.session.state != RaceSession.State.MODE_SELECT:
		return  # the grid and settings only change before a race
	link.send([Msg.SETUP, {"laps": race.session.lap_count(), "weapons": race.weapons_enabled,
		"style": race.combat_style, "round": race.multiplayer_round, "grid": race.grid_order.duplicate(),
		"races": race.races_started}], true)


func can_start() -> bool:
	return client_ready and link.peers().size() > 0


func on_race_started() -> void:
	if is_host():
		client_ready = false
		remote_input.begin_race(0)
		link.send([Msg.START, race.races_started], true)


## After each simulated tick: snapshot every SNAP_INTERVAL ticks.
func host_after_tick() -> void:
	_tick += 1
	_send_events()
	if _tick % SNAP_INTERVAL == 0:
		link.send([Msg.SNAP, RaceSnapshot.encode(RaceSnapshot.capture(race, _tick))], false)


## New combat events (shots, explosions, destructions, respawns), reliably and
## in order, so the client shows every effect exactly once.
func _send_events() -> void:
	var combat: CombatWorld = race.combat
	if _events_race != race.races_started or combat.events.size() < _sent_events:
		_events_race = race.races_started
		_sent_events = 0
	if combat.events.size() > _sent_events:
		link.send([Msg.EVENTS, race.races_started, _sent_events, combat.events.slice(_sent_events)], true)
		_sent_events = combat.events.size()


## Authoritative final result (reliable, so both computers agree).
func send_results(order: Array) -> void:
	if not is_host():
		return
	_send_events()  # every event of the race reaches the client before its result
	var times := PackedFloat64Array()
	for id in order:
		times.append(race.session.racers[id].finish_time)
	link.send([Msg.RESULTS, PackedInt32Array(order), times], true)


# ---------------------------------------------------------------- client side

## Replaces the race simulation on the client, one physics tick.
func client_tick(_step: float) -> void:
	var state: int = race.session.state
	if state == RaceSession.State.MODE_SELECT:
		if race._menu_pressed(PlayerControls.FIRE):
			local_ready = not local_ready
			_send_ready()
	else:
		var cmd := _local_command()
		input_tick += 1
		link.send([Msg.INPUT, input_tick, cmd.steer, cmd.fire, front_total, rear_total], false)
	_interpolate_cars()


func _send_ready() -> void:
	link.send([Msg.READY, local_ready, race.session.control_mode], true)
	race._show_menu()


## Grid panel line about readiness (whose turn it is).
func status_text() -> String:
	if is_host():
		return "PLAYER 2 READY  -  Fire: start the race" if client_ready else "Waiting for Player 2 to get ready..."
	return "YOU ARE READY  -  waiting for the host to start" if local_ready else "Fire: ready (the host starts the race)"


## Control mode chosen on this computer's grid panel (sent with READY).
func on_local_mode_changed() -> void:
	if is_client() and local_ready:
		_send_ready()


func _local_command() -> Dictionary:
	if input_source.is_valid():
		var c: Dictionary = input_source.call()
		if c.get("front", false):
			front_total += 1
		if c.get("rear", false):
			rear_total += 1
		return c
	if Input.is_action_just_pressed(PlayerControls.FIRE_FRONT):
		front_total += 1
	if Input.is_action_just_pressed(PlayerControls.FIRE_REAR):
		rear_total += 1
	return {"steer": PlayerControls.steer(), "fire": PlayerControls.fire_held()}


func _push_snapshot(snap: Array) -> void:
	var t := RaceSnapshot.tick_of(snap)
	if not snapshots.is_empty() and t <= RaceSnapshot.tick_of(snapshots[-1]):
		return  # late or duplicate
	snapshots.append(snap)
	while snapshots.size() > BUFFER:
		snapshots.pop_front()
	RaceSnapshot.apply_race(race, snap)


## Cars shown INTERP_DELAY ticks behind the newest snapshot, blended between
## the two snapshots around that moment (smooth despite 30 Hz / jitter / loss).
func _interpolate_cars() -> void:
	if snapshots.is_empty():
		return
	var newest := float(RaceSnapshot.tick_of(snapshots[-1]))
	var target := newest - INTERP_DELAY
	if render_tick < 0.0 or absf(render_tick - target) > 30.0:
		render_tick = target
	else:
		render_tick += 1.0 + clampf((target - render_tick) * 0.1, -0.5, 0.5)
	render_tick = minf(render_tick, newest)
	var a: Array = snapshots[0]
	var b: Array = snapshots[0]
	for s in snapshots:
		if RaceSnapshot.tick_of(s) <= render_tick:
			a = s
		else:
			b = s
			break
	if RaceSnapshot.tick_of(b) < RaceSnapshot.tick_of(a):
		b = a
	if b.size() > 6:
		RaceSnapshot.apply_combat(race.combat, b[6])  # weapons and wrecks at the moment shown
	var span := float(RaceSnapshot.tick_of(b) - RaceSnapshot.tick_of(a))
	var t := 0.0 if span <= 0.0 else clampf((render_tick - RaceSnapshot.tick_of(a)) / span, 0.0, 1.0)
	for c in race.cars.size():
		var sa := RaceSnapshot.car_state(a, c)
		var sb := RaceSnapshot.car_state(b, c)
		if not sb.present:
			continue
		var car: Car = race.cars[c]
		var pos: Vector2 = sa.position.lerp(sb.position, t)
		var heading := lerp_angle(sa.heading, sb.heading, t)
		car.global_position = pos
		car.global_rotation = heading
		car.model.position = pos
		car.model.heading = heading
		car.model.velocity = sa.velocity.lerp(sb.velocity, t)


# ------------------------------------------------------------------ messages

func _on_message(from: int, msg: Array) -> void:
	match msg[0]:
		Msg.INPUT:
			if is_host() and msg.size() >= 6:
				remote_input.receive(msg[1], msg[2], msg[3], msg[4], msg[5])
		Msg.READY:
			if is_host() and msg.size() >= 3 and race.session.state == RaceSession.State.MODE_SELECT:
				client_ready = msg[1]
				client_mode = msg[2]
				race.set_player_control_mode(RaceSession.PLAYER_2_ID, client_mode)
				race.on_network_peer_ready(client_ready)
		Msg.HELLO:
			if is_host():
				peer_id = from
				send_setup()
		Msg.SETUP:
			if is_client() and race.session.state != RaceSession.State.RACING:
				local_ready = false
				snapshots.clear()
				render_tick = -1.0
				race.apply_network_setup(msg[1])
		Msg.START:
			if is_client():
				race.on_network_start(msg[1])
		Msg.SNAP:
			if is_client():
				var snap := RaceSnapshot.decode(msg[1])
				if snap.size() >= 6:
					_push_snapshot(snap)
		Msg.EVENTS:
			if is_client() and msg.size() >= 4 and msg[1] == race.races_started:
				var events: Array = race.combat.events
				if msg[2] == events.size():  # in order, no gaps or repeats
					events.append_array(msg[3])
		Msg.RESULTS:
			if is_client():
				race.apply_network_results(msg[1], msg[2])
