extends Node2D
## Composition root: one circuit, the player car plus the nine recurring rivals,
## camera and HUD. Owns the asset resolver and wires modules together through
## explicit calls/signals. Racer id == index in cars; 0 is the player, 1..9 are
## the rivals of RivalRoster.
## Modes (chosen on the menu): a race with the player in either control mode, or
## spectating the nine rivals race back to back, at normal or fast simulation.
## Presentation (scenery, effects, audio, HUD extras) only reads race state; it
## can be switched off with presentation_enabled without changing the race.
## Combat (M3): Weapons ON / No Guns is chosen before each race; when on, every
## car follows the same WeaponRules through one deterministic CombatWorld.

## Esc on the grid when allow_exit is set (the title screen listens).
signal exit_requested

enum Choice { FIRE_TO_ACCELERATE, FIRE_TO_BRAKE, SPECTATE }

const CAR_SCENE := preload("res://src/driving/car.tscn")
const MAX_OPPONENTS := 9
const BASE_TICKS := 60
## Spectator: simulated seconds the result stays up before the next race starts.
const RESTART_DELAY := 3.0
## Spectator safety net (not an original rule): only if no unfinished car has
## made any progress for this long (a genuinely stuck race) are the remaining
## cars classified in running order. Long races are never cut short.
const STUCK_RACE_TIMEOUT := 60.0
## Selectable race lengths (laps); the default is the first.
const LAP_OPTIONS: Array[int] = [3, 7, 20, 50]

@export var driving_params: DrivingParams = preload("res://src/driving/default_driving_params.tres")
@export var ai_params: AiParams = preload("res://src/ai/default_ai_params.tres")
## Computer opponents (0-9). The original field is 10 cars: the player + 9.
@export_range(0, MAX_OPPONENTS) var opponent_count := MAX_OPPONENTS
## Player's grid slot in the first race (0 = pole, -1 = back of the grid). PROVISIONAL:
## the original's first-race grid order is unverified; later races use the reversed result.
@export var player_first_grid_slot := -1
## Base seed for the rivals' decision randomness. Same seed + same race number
## = same decisions (used to compare normal and fast simulation).
@export var base_seed := 1991
## Simulation multiplier used by the spectator "fast" option.
@export_range(2, 16) var fast_multiplier := 4
## Scenery, effects and audio. Off = bare race (used to prove they change nothing).
@export var presentation_enabled := true
## Esc on the grid asks to leave (set by the title screen).
@export var allow_exit := false
@export var weapon_rules: WeaponRules = preload("res://src/combat/default_weapon_rules.tres")

var resolver: AssetResolver
var session: RaceSession
var racing_line: RacingLine
var cars: Array[Car] = []
var drivers: Array[AiDriver] = []
var progress: Array[RaceProgress] = []
## grid_order[slot] = racer id, for the current mode.
var grid_order: Array[int] = []
var menu_choice: Choice = Choice.FIRE_TO_ACCELERATE
## Races started so far (seeds the rivals' decisions).
var races_started := 0
var history: RaceHistory
var director := SpectatorDirector.new()
var sim_speed := 1
var _race_grid: Array[int] = []
var _spectator_grid: Array[int] = []
var _restart_timer := -1.0
var _stuck_time := 0.0
var _best_progress := -INF
var effects: RaceEffects
var race_audio: RaceAudio
var scenery: TrackScenery
var _seen_finishers := 0
## Combat simulation for the current race (stepped only with weapons enabled).
var combat: CombatWorld
## Pre-race option: Weapons ON (true) / No Guns (false). Kept across races.
var weapons_enabled := false
var combat_view: CombatView
## Lighting pilot (presentation experiment; L toggles). Off by default.
var lighting: LightingPilot
## Start with the lighting pilot on (e.g. for comparison runs).
@export var lighting_on_start := false

@onready var track: Track = $Track
@onready var car: Car = $Car
@onready var camera: FollowCamera = $FollowCamera
@onready var hud: Hud = $Hud


func _ready() -> void:
	PlayerControls.ensure_actions()
	resolver = AssetResolver.new()
	track.build(resolver)
	track.checkpoint_reached.connect(_on_checkpoint_reached)
	var names := PackedStringArray(["YOU"])
	for i in range(1, opponent_count + 1):
		names.append(RivalRoster.short_name(i))
	session = RaceSession.new(track.checkpoint_count(), track.layout.lap_count, names)
	hud.setup(resolver)
	var decals := Node2D.new()
	decals.name = "Decals"
	add_child(decals)
	move_child(decals, track.get_index() + 1)
	if presentation_enabled:
		scenery = TrackScenery.new()
		scenery.name = "Scenery"
		add_child(scenery)
		move_child(scenery, decals.get_index() + 1)
		scenery.build(track, resolver, decals)
	camera.target = car
	racing_line = RacingLine.new(track.path, track.layout.road_width, driving_params, ai_params)

	car.racer_id = RaceSession.PLAYER_ID
	car.setup(driving_params, session.control_mode, resolver.get_texture(AssetCatalog.CAR_PLAYER))
	cars.append(car)
	drivers.append(null)
	var rival_ids: Array[int] = []
	var car_textures := {}
	var full_names := {}
	for i in range(1, opponent_count + 1):
		var ai_car: Car = CAR_SCENE.instantiate()
		ai_car.name = "AiCar%d" % i
		ai_car.racer_id = i
		add_child(ai_car)
		move_child(ai_car, car.get_index())
		var texture := resolver.get_texture(AssetCatalog.ai_car(i))
		ai_car.setup(driving_params, CarModel.ControlMode.FIRE_TO_ACCELERATE, texture)
		cars.append(ai_car)
		var params: AiParams = load(RivalRoster.params_path(i)) if RivalRoster.has_personality(i) else ai_params
		drivers.append(AiDriver.new(racing_line, params))
		rival_ids.append(i)
		car_textures[i] = texture
		full_names[i] = RivalRoster.full_name(i)
	for c in cars:
		progress.append(RaceProgress.new(track.path))
	combat = CombatWorld.new(weapon_rules, cars.size(), track.path, track.layout.road_width * 0.5)
	history = RaceHistory.new(rival_ids)
	hud.setup_history(resolver, history, car_textures, full_names)
	car_textures[RaceSession.PLAYER_ID] = resolver.get_texture(AssetCatalog.CAR_PLAYER)
	full_names[RaceSession.PLAYER_ID] = "YOU"
	hud.set_field(car_textures, full_names)
	if presentation_enabled:
		effects = RaceEffects.new()
		effects.name = "Effects"
		add_child(effects)
		effects.setup(cars, resolver, decals)
		race_audio = RaceAudio.new()
		race_audio.name = "RaceAudio"
		add_child(race_audio)
		race_audio.setup(cars, resolver, self)
		combat_view = CombatView.new()
		combat_view.name = "CombatView"
		add_child(combat_view)
		combat_view.setup(combat, cars, resolver, race_audio)
		lighting = LightingPilot.new()
		lighting.name = "LightingPilot"
		add_child(lighting)
		lighting.setup(track, cars, combat, resolver)
		lighting.set_enabled(lighting_on_start)
	_race_grid = first_grid(cars.size(), player_first_grid_slot)
	_spectator_grid = rival_ids.duplicate()
	grid_order = _race_grid
	reset_race()


func _exit_tree() -> void:
	set_sim_speed(1)


## Opponents fill the grid in id order around the player's slot.
static func first_grid(field_size: int, player_slot: int) -> Array[int]:
	var slot := field_size - 1 if player_slot < 0 else mini(player_slot, field_size - 1)
	var order: Array[int] = []
	var next_ai := 1
	for s in field_size:
		if s == slot:
			order.append(RaceSession.PLAYER_ID)
		else:
			order.append(next_ai)
			next_ai += 1
	return order


## Simulation throughput multiplier. Every physics tick still advances the race by
## exactly Car.FIXED_STEP with the same AI inputs and collision calculations; fast
## mode only runs more ticks per real second.
func set_sim_speed(multiplier: int) -> void:
	sim_speed = maxi(1, multiplier)
	Engine.physics_ticks_per_second = BASE_TICKS * sim_speed
	Engine.time_scale = sim_speed
	Engine.max_physics_steps_per_frame = maxi(8, sim_speed * 2)
	if effects != null:
		effects.set_enabled(sim_speed == 1)
	if race_audio != null:
		race_audio.fast = sim_speed > 1
	if combat_view != null:
		combat_view.set_enabled(sim_speed == 1)


## Race length in laps (3 / 7 / 20 / 50); only before the start. Kept for every
## following race, including spectator auto-restarts.
func set_lap_count(laps: int) -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	session.set_lap_count(laps)
	reset_race()


func lap_count() -> int:
	return session.lap_count()


## Weapons ON / No Guns; only changeable before the start.
func set_weapons_enabled(on: bool) -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	weapons_enabled = on
	combat.enabled = on
	hud.show_menu(choice_name(menu_choice), weapons_enabled, session.lap_count())


func reset_race() -> void:
	session.reset()
	combat.reset()
	combat.enabled = weapons_enabled
	_restart_timer = -1.0
	_stuck_time = 0.0
	_best_progress = -INF
	_show_player_car(not session.spectator)
	for slot in grid_order.size():
		var id := grid_order[slot]
		var c := cars[id]
		c.active = false
		c.place(track.grid_transform(slot))
		progress[id].reset(c.global_position)
		session.set_progress(id, progress[id].distance)
	_update_camera_target()
	camera.snap_to_target()
	hud.history_panel.visible = session.spectator
	_seen_finishers = 0
	if effects != null:
		effects.clear_marks()
	if race_audio != null:
		race_audio.play_music("menu")
	_refresh_hud()
	hud.show_menu(choice_name(menu_choice), weapons_enabled, session.lap_count())


static func choice_name(choice: Choice) -> String:
	match choice:
		Choice.FIRE_TO_BRAKE: return "FIRE TO BRAKE"
		Choice.SPECTATE: return "SPECTATE RIVALS"
	return "FIRE TO ACCELERATE"


func set_menu_choice(choice: Choice) -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	menu_choice = choice
	var spectate := choice == Choice.SPECTATE
	if not spectate:
		session.control_mode = CarModel.ControlMode.FIRE_TO_BRAKE if choice == Choice.FIRE_TO_BRAKE else CarModel.ControlMode.FIRE_TO_ACCELERATE
	if spectate != session.spectator:
		session.set_spectator(spectate)
		grid_order = _spectator_grid if spectate else _race_grid
		reset_race()
	hud.show_menu(choice_name(menu_choice), weapons_enabled, session.lap_count())


func _physics_process(_delta: float) -> void:
	var step := Car.FIXED_STEP
	match session.state:
		RaceSession.State.MODE_SELECT:
			if Input.is_action_just_pressed(PlayerControls.STEER_LEFT):
				set_menu_choice(posmod(menu_choice - 1, 3) as Choice)
			elif Input.is_action_just_pressed(PlayerControls.STEER_RIGHT):
				set_menu_choice(posmod(menu_choice + 1, 3) as Choice)
			elif Input.is_action_just_pressed(PlayerControls.FIRE_FRONT) or Input.is_action_just_pressed(PlayerControls.FIRE_REAR):
				set_weapons_enabled(not weapons_enabled)
			elif Input.is_action_just_pressed(PlayerControls.HISTORY_VIEW):
				var i := LAP_OPTIONS.find(session.lap_count())
				set_lap_count(LAP_OPTIONS[(i + 1) % LAP_OPTIONS.size()])
			elif Input.is_action_just_pressed(PlayerControls.FIRE):
				start_race()
			elif allow_exit and Input.is_action_just_pressed(PlayerControls.BACK):
				exit_requested.emit()
			return
		RaceSession.State.RACING:
			if not session.spectator:
				car.steer = PlayerControls.steer()
				car.fire = PlayerControls.fire_held()
		RaceSession.State.FINISHED:
			if not session.spectator:
				# After the flag the player has no control; the car brakes to a stop.
				car.steer = 0.0
				car.fire = car.model.control_mode == CarModel.ControlMode.FIRE_TO_BRAKE
				if Input.is_action_just_pressed(PlayerControls.FIRE):
					_race_grid = session.reversed_grid()
					grid_order = _race_grid
					reset_race()
					return
	if session.spectator and _spectator_input():
		return
	_update_progress()
	_drive_opponents(step)
	if combat.enabled:
		_combat_tick(step)
	session.tick(step)
	if session.spectator:
		_spectator_tick(step)
	_update_camera_target(step)


func start_race() -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	races_started += 1
	car.model.control_mode = session.control_mode
	for id in grid_order:
		cars[id].active = true
		if drivers[id] != null:
			drivers[id].begin_race(race_seed(races_started, id))
	session.start()
	hud.hide_message()
	hud.flash_banner("GO!")
	if race_audio != null:
		race_audio.play_cue("race/start_go")
		race_audio.play_music("race")


## Seed of a rival's decisions in a given race (stable across sessions).
func race_seed(race_number: int, racer_id: int) -> int:
	return hash([base_seed, race_number, racer_id])


func _spectator_input() -> bool:
	if Input.is_action_just_pressed(PlayerControls.BACK):
		set_sim_speed(1)
		session.state = RaceSession.State.MODE_SELECT
		grid_order = _spectator_grid
		reset_race()
		return true
	if Input.is_action_just_pressed(PlayerControls.SIM_SPEED):
		set_sim_speed(1 if sim_speed > 1 else fast_multiplier)
	if Input.is_action_just_pressed(PlayerControls.HISTORY_VIEW):
		hud.history_panel.toggle_view()
	if Input.is_action_just_pressed(PlayerControls.TOGGLE_PANEL):
		hud.history_panel.visible = not hud.history_panel.visible
	if Input.is_action_just_pressed(PlayerControls.STEER_LEFT):
		hud.history_panel.scroll_columns(-3)
	if Input.is_action_just_pressed(PlayerControls.STEER_RIGHT):
		hud.history_panel.scroll_columns(3)
	return false


## Records each finished race, shows the result briefly, then starts the next
## race from the reversed grid.
func _spectator_tick(step: float) -> void:
	if session.state == RaceSession.State.RACING:
		var furthest := -INF
		for r in session.participants():
			if not r.is_finished():
				furthest = maxf(furthest, r.progress + r.tracker.laps_completed * 100000.0)
		if furthest > _best_progress + 1.0:
			_best_progress = furthest
			_stuck_time = 0.0
		else:
			_stuck_time += step
		if _stuck_time > STUCK_RACE_TIMEOUT:
			session.classify_remaining()
	if session.state == RaceSession.State.FINISHED:
		if _restart_timer < 0.0:
			history.add_race(session.finish_order, weapons_enabled, session.lap_count())
			hud.history_panel.refresh()
			_restart_timer = RESTART_DELAY
			hud.show_results(session.standings(), "Next race starting...")
		_restart_timer -= step
		if _restart_timer <= 0.0:
			_spectator_grid = session.reversed_grid()
			grid_order = _spectator_grid
			reset_race()
			start_race()


func _show_player_car(on: bool) -> void:
	car.visible = on
	car.collision_layer = 2 if on else 0
	car.collision_mask = 3 if on else 0
	if not on:
		car.active = false
		car.place(Transform2D(0.0, Vector2(-100000, -100000)))


func _update_camera_target(step: float = 0.0) -> void:
	if not session.spectator:
		camera.target = car
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2.ONE
		return
	var view: Array = []
	for r in session.participants():
		view.append({"id": r.id, "progress": r.progress, "finished": r.is_finished()})
	var id := director.update(view, step)
	if id > 0:
		camera.target = cars[id]
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.zoom = Vector2(0.85, 0.85)


func _process(_delta: float) -> void:
	if lighting != null and Input.is_action_just_pressed(PlayerControls.TOGGLE_LIGHTING):
		lighting.set_enabled(not lighting.enabled)
	_refresh_hud()
	_present_finishers()


## Finish celebrations (presentation only): the player's finish in a race, the
## winner's finish when spectating.
func _present_finishers() -> void:
	var count := session.finish_order.size()
	if count <= _seen_finishers:
		_seen_finishers = mini(_seen_finishers, count)
		return
	for k in range(_seen_finishers, count):
		var id: int = session.finish_order[k]
		var celebrate := (id == RaceSession.PLAYER_ID and not session.spectator) or (session.spectator and k == 0)
		if celebrate:
			hud.flash_banner("FINISH!" if not session.spectator else "%s WINS!" % RivalRoster.short_name(id).to_upper())
			if effects != null:
				effects.celebrate(track.checkpoint_transform(0).origin)
			if race_audio != null:
				race_audio.play_cue("race/finish")
	_seen_finishers = count


func _refresh_hud() -> void:
	hud.update_tower(session.standings())
	if session.spectator:
		var leader := session.standings()[0] if session.racer_count() > 0 else null
		var following := RivalRoster.short_name(director.target_id) if director.target_id > 0 else "-"
		hud.update_spectator(history.race_count() + (0 if session.state == RaceSession.State.FINISHED else 1),
			leader.tracker.current_lap() if leader != null else 1, session.racers[0].tracker.lap_count,
			session.elapsed, "x%d" % sim_speed, following, weapons_enabled)
		hud.update_combat(false, 0, 0, 0, 0, 0.0)
		return
	var p := session.racers[RaceSession.PLAYER_ID]
	var time := p.finish_time if p.is_finished() else session.elapsed
	hud.update_race(p.tracker.current_lap(), p.tracker.lap_count, time,
		session.position_of(RaceSession.PLAYER_ID), session.racer_count())
	hud.update_combat(weapons_enabled, weapon_rules.front_weapon, combat.ammo[0][CombatWorld.FRONT],
		weapon_rules.rear_weapon, combat.ammo[0][CombatWorld.REAR], combat.wreck_left[0])
	if session.state == RaceSession.State.FINISHED:
		hud.show_results(session.standings())


func _update_progress() -> void:
	for id in grid_order:
		progress[id].update(cars[id].global_position)
		session.set_progress(id, progress[id].distance)


func _drive_opponents(step: float) -> void:
	for id in grid_order:
		if drivers[id] == null:
			continue
		var others: Array = []
		for other in grid_order:
			if other != id:
				others.append({"distance": progress[other].distance, "lateral": progress[other].lateral,
					"speed": cars[other].model.forward_speed()})
		var me := {"position": cars[id].global_position, "heading": cars[id].model.heading,
			"speed": cars[id].model.forward_speed(), "distance": progress[id].distance,
			"lateral": progress[id].lateral}
		var out := drivers[id].decide(me, others, step)
		cars[id].steer = out.steer
		cars[id].fire = out.fire


func _on_checkpoint_reached(index: int, body: Node2D) -> void:
	var c := body as Car
	if c == null or not c.active:
		return
	session.checkpoint_reached(index, c.racer_id)


## Combat for one tick: the player's Up/Down presses and the rivals' decisions
## become fire requests, then the combat world advances; destroyed cars stop
## where they are, respawned cars carry on.
func _combat_tick(step: float) -> void:
	var states := _combat_states()
	if session.state == RaceSession.State.RACING and not session.spectator and not combat.is_wrecked(RaceSession.PLAYER_ID):
		if Input.is_action_just_pressed(PlayerControls.FIRE_FRONT):
			combat.request(RaceSession.PLAYER_ID, CombatWorld.FRONT, states)
		if Input.is_action_just_pressed(PlayerControls.FIRE_REAR):
			combat.request(RaceSession.PLAYER_ID, CombatWorld.REAR, states)
	if session.state != RaceSession.State.MODE_SELECT:
		_ai_weapons(step, states)
	var result := combat.step(step, states)
	for id in result.destroyed:
		cars[id].active = false
		cars[id].model.velocity = Vector2.ZERO
		if drivers[id] != null:
			drivers[id].on_destroyed()
	for id in result.respawned:
		cars[id].model.velocity = Vector2.ZERO
		if session.state != RaceSession.State.MODE_SELECT:
			cars[id].active = true


func _combat_states() -> Array:
	var states: Array = []
	for i in cars.size():
		states.append({"position": cars[i].global_position, "heading": cars[i].model.heading,
			"present": grid_order.has(i)})
	return states


func _ai_weapons(step: float, states: Array) -> void:
	for id in grid_order:
		var d := drivers[id]
		if d == null or combat.is_wrecked(id) or session.racers[id].is_finished():
			continue
		var front_ready := combat.can_fire(id, CombatWorld.FRONT)
		var rear_ready := combat.can_fire(id, CombatWorld.REAR)
		if not front_ready and not rear_ready:
			continue
		var targets: Array = []
		for other in grid_order:
			if other == id:
				continue
			targets.append({"position": cars[other].global_position, "velocity": cars[other].model.velocity,
				"distance": progress[other].distance, "lateral": progress[other].lateral,
				"speed": cars[other].model.forward_speed(), "wrecked": combat.is_wrecked(other)})
		var me := {"position": cars[id].global_position, "heading": cars[id].model.heading,
			"speed": cars[id].model.forward_speed(), "distance": progress[id].distance, "lateral": progress[id].lateral}
		var r := session.racers[id]
		var ctx := {"front_ready": front_ready, "rear_ready": rear_ready, "front_ammo": combat.ammo[id][CombatWorld.FRONT],
			"front_start": weapon_rules.ammo_for(CombatWorld.FRONT), "laps_left": r.tracker.lap_count - r.tracker.laps_completed,
			"lap_count": r.tracker.lap_count, "missile_speed": weapon_rules.missile_speed, "hit_radius": weapon_rules.hit_radius,
			"mine_fuse": weapon_rules.mine_fuse,
			"pressure": d.params.pressure_attack_drop > 0.0 and d.under_pressure(me, targets)}
		var out := d.decide_weapons(me, targets, ctx, step)
		if out.front:
			combat.request(id, CombatWorld.FRONT, states)
		if out.rear:
			combat.request(id, CombatWorld.REAR, states)
