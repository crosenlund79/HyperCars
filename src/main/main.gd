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
## Combat style (M3.5), chosen before the race and independent of No Guns:
## Classic (M3 rules and AI) or Tactical (per-slot cooldowns).

## Esc on the grid when allow_exit is set (the title screen listens).
signal exit_requested
## Garage races: the player asked for the garage after a race (the game root opens it).
signal garage_requested
## Read-only race hooks (achievements): a race started; a race's result is final
## (every car finished, or the race was left after the player finished; cars
## still running are placed in running order). Emitted once per race.
signal race_began
signal race_concluded(order: Array)

enum Choice { FIRE_TO_ACCELERATE, FIRE_TO_BRAKE, SPECTATE }

const CAR_SCENE := preload("res://src/driving/car.tscn")
const MAX_OPPONENTS := 9
const BASE_TICKS := 60
## Spectator: simulated seconds the result stays up before the next race starts.
const RESTART_DELAY := 3.0
## GO! stays briefly (seconds before it fades): the start is the busiest moment.
const GO_BANNER_HOLD := 0.3
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
## Track theme variant (1 = baseline). Visual only; set before the scene starts.
@export_range(1, 3) var track_variant := 1
var track_theme: TrackTheme
var hud_track_name := ""
## Track layout for this race scene (null = the classic circuit). The game
## sets it from the title screen's LAYOUT choice; scenes started without the
## game (tests, probes, the editor) may take the developer command line
## (DevLayouts, "--layout=<id>") unless use_command_line_layout is off.
var layout_override: TrackLayout = null
var use_command_line_layout := true
## J1: road level of each car (0 ground, 1 elevated). Always 0 on flat circuits.
var car_levels := PackedInt32Array()
## Cars near a bridge end (transition band): on both levels at once.
var car_transitions := PackedByteArray()
## The Esc race menu (Resume / Leave). While it is open this computer's
## drivers give no commands; a race without network play is paused.
var race_menu: RaceMenu
var menu_open := false
var _menu_paused := false

var resolver: AssetResolver
var session: RaceSession
var racing_line: RacingLine
var cars: Array[Car] = []
## Computer drivers by racer id (null for human-driven cars).
var drivers: Array[AiDriver] = []
## Every car's controls by racer id: humans and AI supply the same commands.
var inputs: Array[DriverInput] = []
var progress: Array[RaceProgress] = []
## grid_order[slot] = racer id, for the current mode.
var grid_order: Array[int] = []
var menu_choice: Choice = Choice.FIRE_TO_ACCELERATE
## Races started so far (seeds the rivals' decisions).
var races_started := 0
var history: RaceHistory
var director := SpectatorDirector.new()
## Spectator: this race's starting grid (fixed order for the camera arrows).
var spectator_start_grid: Array[int] = []
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
## Pre-race option: Classic / Tactical combat. Kept across races.
var combat_style: WeaponRules.Style = WeaponRules.Style.CLASSIC
var combat_view: CombatView
## P2: the images each car is drawn with (index = racer id), see CarArt.look.
var _car_looks: Array[Dictionary] = []
## P2: shared wheel positions and motion (presentation only).
var wheel_layout: WheelLayout = preload("res://src/presentation/default_wheel_layout.tres")
## Chevron over the locally controlled car(s) (presentation only).
var player_marker: PlayerMarker
## Lighting pilot (presentation experiment; L toggles). Off by default.
var lighting: LightingPilot
## Garage race (M3.5): the player's money and weapons for this game session;
## null = quick race (standard loadout, no money). Set before the first race.
var garage: PlayerGarage
## True while the garage screen is open over the grid (grid input paused).
var garage_open := false
var _garage_settled := false
## Physics ticks to ignore grid input after the garage closes (the closing key
## must not also act on the grid panel).
var _grid_input_delay := 0
## Achievements (M3.5): persistent store set by the game root before the scene
## enters the tree; null = no tracking (tests, tools). The tracker only reads.
var achievements: AchievementStore
var achievement_tracker: AchievementTracker
var _race_open := false
## Start with the lighting pilot on (e.g. for comparison runs).
@export var lighting_on_start := false
## M4 two-player races: number of humans (1 or 2), set before the scene starts.
## With 2, Player 2 is racer 10, the field stays 10 cars (2 humans + 8 rivals,
## one rival sitting out per race in a fixed rotation), and the garage and
## achievements are off.
@export_range(1, 2) var human_count := 1
## Two-player: each player's device (joypad id, or PlayerControls.KEYBOARD).
var player_devices: Array[int] = [0, 1]
## Two-player safety net: once someone has finished, a human that makes no
## progress for this long (s) no longer holds up the results.
@export var human_stuck_timeout := 30.0
## Two-player races run so far in this session (drives the rival rotation).
var multiplayer_round := 0
var _human_stuck_time := 0.0
## Two-player split-screen on this computer (couch); off for network races.
var split_screen := true
## Network two-player race (M5.1): the session's NetRace (host or client), set
## before the scene enters the tree; null for local play.
var net: NetRace
## The human this computer shows (camera, HUD): the player, or Player 2 on a
## network client.
var local_player_id := RaceSession.PLAYER_ID
## Per-human control mode overrides (network: each computer chooses its own).
var player_control_modes := {}
## Client: the final finishing order received from the host (empty until then).
var network_results: Array[int] = []
## Network race: the other computer is gone (the race is over; back to the menu).
var network_lost := false
## Two-player split-screen views (M4 Stage 2); null in single-player.
var player_views: PlayerViews
## Two-player: the main camera looks at an empty spot far away (the views draw
## the race); positional sound is heard from between the two players.
var _park: Node2D
var _listener: AudioListener2D
var _human_best := -INF

@onready var track: Track = $Track
@onready var car: Car = $Car
@onready var camera: FollowCamera = $FollowCamera
@onready var hud: Hud = $Hud


func _ready() -> void:
	PlayerControls.ensure_actions()
	resolver = AssetResolver.new()
	track_theme = TrackTheme.load_variant(track_variant)
	if layout_override == null and use_command_line_layout:
		layout_override = DevLayouts.load_selected()
	if layout_override != null:
		track.layout = layout_override
	track.build(resolver, track_theme)
	hud_track_name = "%s  -  %s" % [track_theme.display_name, DevLayouts.display_name(DevLayouts.id_of(layout_override))]
	track.checkpoint_reached.connect(_on_checkpoint_reached)
	var two := is_two_player()
	if two:
		garage = null  # garage and achievement progression are single-player only (M4)
		achievements = null
	var names := PackedStringArray(["P1" if two else "YOU"])
	for i in range(1, opponent_count + 1):
		names.append(RivalRoster.short_name(i))
	if two:
		names.append("P2")
	session = RaceSession.new(track.checkpoint_count(), track.layout.lap_count, names)
	if two:
		session.set_humans([RaceSession.PLAYER_ID, RaceSession.PLAYER_2_ID] as Array[int])
	hud.setup(resolver)
	race_menu = RaceMenu.new()
	race_menu.name = "RaceMenu"
	add_child(race_menu)
	race_menu.setup(HyperTheme.build(resolver))
	race_menu.resume_requested.connect(resume_race)
	race_menu.leave_requested.connect(leave_race)
	hud.follow_requested.connect(follow_driver)
	hud.follow_step_requested.connect(follow_step)
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
	_car_looks.append(CarArt.look(resolver, AssetCatalog.CAR_PLAYER))
	car.setup(driving_params, session.control_mode, _car_looks[0].body)
	cars.append(car)
	drivers.append(null)
	inputs.append(HumanDriverInput.new(RaceSession.PLAYER_ID,
		PlayerControls.ensure_player_actions(1, player_devices[0]) if two and net == null else ""))
	var rival_ids: Array[int] = []
	var car_textures := {}
	var full_names := {}
	for i in range(1, opponent_count + 1):
		var ai_car: Car = CAR_SCENE.instantiate()
		ai_car.name = "AiCar%d" % i
		ai_car.racer_id = i
		add_child(ai_car)
		move_child(ai_car, car.get_index())
		_car_looks.append(CarArt.look(resolver, AssetCatalog.ai_car(i)))
		ai_car.setup(driving_params, CarModel.ControlMode.FIRE_TO_ACCELERATE, _car_looks[i].body)
		cars.append(ai_car)
		var params: AiParams = load(RivalRoster.params_path(i)) if RivalRoster.has_personality(i) else ai_params
		drivers.append(AiDriver.new(racing_line, params))
		inputs.append(AiDriverInput.new(i, drivers[-1]))
		rival_ids.append(i)
		car_textures[i] = CarArt.icon(resolver, AssetCatalog.ai_car(i))
		full_names[i] = RivalRoster.full_name(i)
	if two:
		var car2: Car = CAR_SCENE.instantiate()
		car2.name = "Car2"
		car2.racer_id = RaceSession.PLAYER_2_ID
		add_child(car2)
		move_child(car2, car.get_index() + 1)
		_car_looks.append(CarArt.look(resolver, AssetCatalog.CAR_PLAYER_2))
		car2.setup(driving_params, session.control_mode, _car_looks[-1].body)
		cars.append(car2)
		drivers.append(null)
		if net != null and net.is_host():
			inputs.append(net.remote_input)
		elif net != null:
			inputs.append(HumanDriverInput.new(RaceSession.PLAYER_2_ID))  # the client never simulates
		else:
			inputs.append(HumanDriverInput.new(RaceSession.PLAYER_2_ID, PlayerControls.ensure_player_actions(2, player_devices[1])))
	for c in cars:
		progress.append(RaceProgress.new(track.path))
	car_levels.resize(cars.size())
	car_transitions.resize(cars.size())
	combat = CombatWorld.new(weapon_rules, cars.size(), track.path, track.layout.road_width * 0.5)
	if track.layout.has_elevation():
		combat.layout = track.layout
	history = RaceHistory.new(rival_ids)
	hud.setup_history(resolver, history, car_textures, full_names)
	car_textures[RaceSession.PLAYER_ID] = CarArt.icon(resolver, AssetCatalog.CAR_PLAYER)
	full_names[RaceSession.PLAYER_ID] = "PLAYER 1" if two else "YOU"
	if two:
		car_textures[RaceSession.PLAYER_2_ID] = CarArt.icon(resolver, AssetCatalog.CAR_PLAYER_2)
		full_names[RaceSession.PLAYER_2_ID] = "PLAYER 2"
	hud.set_field(car_textures, full_names)
	if presentation_enabled:
		effects = RaceEffects.new()
		effects.name = "Effects"
		add_child(effects)
		effects.setup(cars, resolver, decals, track_theme.dust_color)
		race_audio = RaceAudio.new()
		race_audio.name = "RaceAudio"
		add_child(race_audio)
		race_audio.setup(cars, resolver, self)
		combat_view = CombatView.new()
		combat_view.name = "CombatView"
		add_child(combat_view)
		combat_view.setup(combat, cars, resolver, race_audio)
		combat_view.human_ids = session.human_ids
		if track.layout.has_elevation():  # J2: bridge-level effects draw above the deck
			effects.setup_levels(level_of, decals)
			combat_view.setup_levels(level_of)
		var wheel := resolver.get_texture(AssetCatalog.WHEEL)
		for k in cars.size():  # four shared wheels under each body (not for flattened custom cars)
			if _car_looks[k].wheels:
				CarWheels.new().setup(cars[k], wheel, wheel_layout, _car_looks[k].body_logical)
		player_marker = PlayerMarker.new()
		player_marker.name = "PlayerMarker"
		add_child(player_marker)
		player_marker.setup(cars)
		lighting = LightingPilot.new()
		lighting.name = "LightingPilot"
		add_child(lighting)
		lighting.setup(track, cars, combat, resolver)
		if track.layout.has_elevation():
			lighting.level_of = draw_level_of
		lighting.set_enabled(lighting_on_start)
	if achievements != null:
		achievement_tracker = AchievementTracker.new()
		achievement_tracker.name = "AchievementTracker"
		add_child(achievement_tracker)
		achievement_tracker.setup(self, achievements)
	if net != null:
		split_screen = false
		local_player_id = RaceSession.PLAYER_2_ID if net.is_client() else RaceSession.PLAYER_ID
		add_child(net)
	if two and split_screen:
		_setup_split_screen()
	_set_hud_humans()
	_race_grid = first_grid_two_players(sitting_out_rival(0)) if two else first_grid(cars.size(), player_first_grid_slot)
	_spectator_grid = rival_ids.duplicate()
	grid_order = _race_grid
	reset_race()
	if net != null:
		net.attach(self)


func _exit_tree() -> void:
	if _menu_paused:  # never leave the game paused behind a freed race
		get_tree().paused = false
		_menu_paused = false
	set_sim_speed(1)
	_conclude_race()
	if garage != null and garage.race_pending():
		garage.abandon_race()


## Presentation: identity colours of the humans in the standings and results
## (Player 1 gold, Player 2 blue; over the network each computer shows itself
## gold). Each HUD box-highlights its own human(s).
func _set_hud_humans() -> void:
	var colors := {}
	for k in session.human_ids.size():
		var id: int = session.human_ids[k]
		colors[id] = HyperTheme.player_color(k)
		if net != null:
			colors[id] = HyperTheme.player_color(0 if id == local_player_id else 1)
	var own: Array[int] = [local_player_id]
	if player_views != null:
		own = session.human_ids.duplicate()
		for v in player_views.views:
			v.hud.copy_field_from(hud)
			v.hud.set_humans(colors, [v.racer_id] as Array[int])
	hud.set_humans(colors, own)
	if player_marker != null:  # only the car(s) controlled on this computer
		var marked := {}
		for id in own:
			marked[id] = colors[id]
		player_marker.set_marked(marked)
	if race_audio != null:  # own car(s) always heard, rivals limited to the nearest
		race_audio.local_ids = own


func is_two_player() -> bool:
	return human_count > 1


func _setup_split_screen() -> void:
	player_views = PlayerViews.new()
	player_views.name = "PlayerViews"
	add_child(player_views)
	player_views.setup(session.human_ids, cars, get_viewport().world_2d, resolver)
	hud.layer = 4
	hud.set_info_visible(false)
	hud.set_tower_visible(false)  # each view shows its own standings at its outer edge
	hud.set_message_min_top(PlayerViews.INFO_BOTTOM)  # grid panel / results below both info panels
	hud.set_banner_low(true)
	_park = Node2D.new()
	_park.name = "CameraPark"
	_park.position = Vector2(-1000000, -1000000)
	add_child(_park)
	_listener = AudioListener2D.new()
	add_child(_listener)
	_listener.make_current()


## Two-player rotation: the rival sitting out race r (0-based), Victor first,
## then Rocco ... Nina, and round again.
static func sitting_out_rival(race_round: int) -> int:
	return race_round % RivalRoster.count() + 1


## First two-player grid: the eight racing rivals in id order, then Player 2,
## then Player 1 at the back (as the single player starts last).
static func first_grid_two_players(sitting_out: int) -> Array[int]:
	var order: Array[int] = []
	for i in range(1, RivalRoster.count() + 1):
		if i != sitting_out:
			order.append(i)
	order.append(RaceSession.PLAYER_2_ID)
	order.append(RaceSession.PLAYER_ID)
	return order


## Next two-player grid: the reversed result, with the rival whose turn it is
## to sit out replaced, in the same slot, by the rival returning from sitting
## out. Everyone else keeps their reversed-grid slot.
static func rotated_grid(reversed: Array[int], leaving: int, returning: int) -> Array[int]:
	var order := reversed.duplicate()
	var slot := order.find(leaving)
	if slot >= 0:
		order[slot] = returning
	return order


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
	_show_menu()


## Classic / Tactical combat; only changeable before the start.
func set_combat_style(style: WeaponRules.Style) -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	combat_style = style
	reset_race()


func _show_menu() -> void:
	if network_lost:
		return
	hud.track_name = hud_track_name
	hud.show_menu(choice_name(menu_choice), weapons_enabled, session.lap_count(), combat_style,
		net.status_text() if net != null and net.race != null else "")
	if net != null and net.is_host():
		net.send_setup()


func reset_race() -> void:
	_conclude_race()
	_race_open = false
	_human_stuck_time = 0.0
	_human_best = -INF
	if garage != null and garage.race_pending():
		garage.abandon_race()
	_garage_settled = false
	session.reset()
	if is_two_player():
		session.set_sitting_out([sitting_out_rival(multiplayer_round)] as Array[int])
	combat.reset()
	combat.enabled = weapons_enabled
	combat.style = combat_style
	_apply_loadouts()
	_restart_timer = -1.0
	_stuck_time = 0.0
	_best_progress = -INF
	car_levels.fill(0)  # the grid is on the ground
	car_transitions.fill(0)
	for id in cars.size():
		_show_car(id, grid_order.has(id))
	for slot in grid_order.size():
		var id := grid_order[slot]
		var c := cars[id]
		c.active = false
		c.place(track.grid_transform(slot))
		progress[id].reset(c.global_position)
		session.set_progress(id, progress[id].distance)
	if session.spectator:
		_follow_last_starter()
	_update_camera_target()
	camera.snap_to_target()
	hud.history_panel.visible = session.spectator
	hud.set_banner_low(session.spectator or player_views != null)  # clear of the history panel at the top
	_seen_finishers = 0
	if effects != null:
		effects.clear_marks()
	if race_audio != null:
		race_audio.play_music("menu")
	_refresh_hud()
	_show_menu()


## Weapons each car carries this race. Classic: everyone gets the M3 loadout.
## Tactical: each rival has a personal loadout of equal value (RivalArmoury).
## The player: the garage's equipped rounds in a garage race; otherwise the
## standard loadout of the style (quick races never touch the garage).
func _apply_loadouts() -> void:
	if combat_style == WeaponRules.Style.TACTICAL:
		for id in range(1, cars.size()):
			var l := RivalArmoury.loadout(id)
			combat.set_loadout(id, l[0], l[1], l[2], l[3])
	if session.spectator:
		return
	if garage != null:
		var g := garage.race_loadout()
		combat.set_loadout(RaceSession.PLAYER_ID, g[0], g[1], g[2], g[3])
	elif combat_style == WeaponRules.Style.TACTICAL:
		var q := RivalArmoury.QUICK_RACE_PLAYER
		combat.set_loadout(RaceSession.PLAYER_ID, q[0], q[1], q[2], q[3])


## Two-player safety net: once anyone has finished, unfinished humans that make
## no progress at all for human_stuck_timeout seconds stop holding up the
## results (an active, moving player is never cut short).
func _human_safety(step: float) -> void:
	if session.state != RaceSession.State.RACING or session.finish_order.is_empty():
		return
	var furthest := -INF
	for id in session.human_ids:
		var r := session.racers[id]
		if session.is_participating(id) and not r.is_finished():
			furthest = maxf(furthest, r.progress + r.tracker.laps_completed * 100000.0)
	if furthest > _human_best + 1.0:
		_human_best = furthest
		_human_stuck_time = 0.0
	else:
		_human_stuck_time += step
	if _human_stuck_time > human_stuck_timeout:
		session.end_for_humans()


# ------------------------------------------------- network two-player (M5.1)

## A human's own control mode (network: chosen on their own computer).
func set_player_control_mode(id: int, mode: CarModel.ControlMode) -> void:
	player_control_modes[id] = mode


## The other computer disconnected: everything stops and a clear message
## offers the way back to the menu. Nothing is saved (garage / achievements are
## off in network races).
func on_network_lost(text: String) -> void:
	if menu_open:
		resume_race()
	if network_lost:
		return
	network_lost = true
	for c in cars:
		c.active = false
	if race_audio != null:
		race_audio.play_music("menu")
	hud.show_notice("CONNECTION LOST", text, "Fire / Esc: back to the menu")


## Host: the client readied up or cancelled (shown on the grid panel).
func on_network_peer_ready(_is_ready: bool) -> void:
	_show_menu()


## Client: the host's grid and settings for the next race.
func apply_network_setup(cfg: Dictionary) -> void:
	session.state = RaceSession.State.MODE_SELECT
	weapons_enabled = cfg.weapons
	combat_style = cfg.style
	multiplayer_round = cfg.round
	races_started = cfg.races
	if session.lap_count() != cfg.laps:
		session.set_lap_count(cfg.laps)
	var grid: Array[int] = []
	for id in cfg.grid:
		grid.append(id)
	_race_grid = grid
	grid_order = grid
	reset_race()


## Client: the host started the race (number `race_number`).
func on_network_start(race_number: int = races_started) -> void:
	races_started = race_number
	cars[local_player_id].model.control_mode = session.control_mode  # predicted with this player's own mode
	combat.reset()
	combat.enabled = weapons_enabled
	combat.style = combat_style
	_apply_loadouts()
	hud.hide_message()
	hud.flash_banner("GO!", HyperTheme.GOLD, GO_BANNER_HOLD)
	if race_audio != null:
		race_audio.play_cue("race/start_go")
		race_audio.play_music("race")


## Client: the host's final result (reliable; overrides any older snapshot).
func apply_network_results(order: PackedInt32Array, times: PackedFloat64Array) -> void:
	var finish: Array[int] = []
	for k in order.size():
		var r := session.racers[order[k]]
		r.finish_position = k + 1
		r.finish_time = times[k]
		finish.append(order[k])
	session.finish_order = finish
	session.state = RaceSession.State.FINISHED
	network_results = finish


## Client physics tick: no simulation, only the network side and the camera.
func _client_physics(step: float) -> void:
	if session.state == RaceSession.State.MODE_SELECT and _grid_input_delay <= 0:
		if _menu_pressed(PlayerControls.STEER_LEFT):
			set_menu_choice(posmod(menu_choice - 1, 2) as Choice)
			net.on_local_mode_changed()
		elif _menu_pressed(PlayerControls.STEER_RIGHT):
			set_menu_choice(posmod(menu_choice + 1, 2) as Choice)
			net.on_local_mode_changed()
		elif allow_exit and _menu_pressed(PlayerControls.BACK):
			exit_requested.emit()
	net.client_tick(step)
	_update_camera_target(step)


## Reports the race result once it is final (see race_concluded). Only a race
## that reached the flag counts; one left while racing is not reported.
func _conclude_race() -> void:
	if not _race_open or session.state != RaceSession.State.FINISHED:
		return
	_race_open = false
	var order: Array = []
	for r in session.standings():
		order.append(r.id)
	race_concluded.emit(order)
	if net != null:
		net.send_results(order)


## Garage race: once the player has finished, pays the prize and keeps the
## rounds left (exactly once per race; the garage also guards against repeats).
func _settle_garage() -> void:
	if garage == null or session.spectator or _garage_settled or session.state != RaceSession.State.FINISHED:
		return
	_garage_settled = true
	garage.settle_race(session.racers[RaceSession.PLAYER_ID].finish_position,
		combat.ammo[RaceSession.PLAYER_ID][CombatWorld.FRONT], combat.ammo[RaceSession.PLAYER_ID][CombatWorld.REAR])


## Opens the garage between races (garage races only).
func open_garage() -> void:
	if garage == null or session.state != RaceSession.State.MODE_SELECT:
		return
	garage_open = true
	hud.hide_message()
	garage_requested.emit()


## Garage closed: the new purchases / equipment are loaded, then the race
## starts (start) or the grid panel is shown.
func close_garage(start: bool) -> void:
	garage_open = false
	_grid_input_delay = 3
	if session.state != RaceSession.State.MODE_SELECT:
		return
	reset_race()
	if start:
		start_race()


static func choice_name(choice: Choice) -> String:
	match choice:
		Choice.FIRE_TO_BRAKE: return "FIRE TO BRAKE"
		Choice.SPECTATE: return "SPECTATE RIVALS"
	return "FIRE TO ACCELERATE"


func set_menu_choice(choice: Choice) -> void:
	if session.state != RaceSession.State.MODE_SELECT or (is_two_player() and choice == Choice.SPECTATE):
		return
	menu_choice = choice
	var spectate := choice == Choice.SPECTATE
	if not spectate:
		session.control_mode = CarModel.ControlMode.FIRE_TO_BRAKE if choice == Choice.FIRE_TO_BRAKE else CarModel.ControlMode.FIRE_TO_ACCELERATE
	if spectate != session.spectator:
		session.set_spectator(spectate)
		grid_order = _spectator_grid if spectate else _race_grid
		reset_race()
	_show_menu()


func _physics_process(_delta: float) -> void:
	var step := Car.FIXED_STEP
	if network_lost:
		if _menu_pressed(PlayerControls.FIRE) or _menu_pressed(PlayerControls.BACK):
			exit_requested.emit()
		return
	if net != null and net.is_client():
		_client_physics(step)
		return
	_settle_garage()
	match session.state:
		RaceSession.State.MODE_SELECT:
			if garage_open:
				return
			if _grid_input_delay > 0:
				_grid_input_delay -= 1
				return
			var choices := 2 if is_two_player() else 3  # no spectating in two-player races
			if _menu_pressed(PlayerControls.STEER_LEFT):
				set_menu_choice(posmod(menu_choice - 1, choices) as Choice)
			elif _menu_pressed(PlayerControls.STEER_RIGHT):
				set_menu_choice(posmod(menu_choice + 1, choices) as Choice)
			elif _menu_pressed(PlayerControls.FIRE_FRONT) or _menu_pressed(PlayerControls.FIRE_REAR):
				set_weapons_enabled(not weapons_enabled)
			elif _menu_pressed(PlayerControls.TOGGLE_STYLE):
				set_combat_style(WeaponRules.Style.TACTICAL if combat_style == WeaponRules.Style.CLASSIC else WeaponRules.Style.CLASSIC)
			elif _menu_pressed(PlayerControls.HISTORY_VIEW):
				var i := LAP_OPTIONS.find(session.lap_count())
				set_lap_count(LAP_OPTIONS[(i + 1) % LAP_OPTIONS.size()])
			elif _menu_pressed(PlayerControls.FIRE):
				if net == null or net.can_start():
					start_race()
			elif allow_exit and _menu_pressed(PlayerControls.BACK):
				exit_requested.emit()
			return
		RaceSession.State.FINISHED:
			if not session.spectator:
				var skip_garage := garage != null and _menu_pressed(PlayerControls.HISTORY_VIEW)
				if _menu_pressed(PlayerControls.FIRE) or skip_garage:
					if is_two_player():
						var leaving := sitting_out_rival(multiplayer_round + 1)
						var returning := sitting_out_rival(multiplayer_round)
						multiplayer_round += 1
						_race_grid = rotated_grid(session.reversed_grid(), leaving, returning)
						grid_order = _race_grid
						reset_race()
						return
					_race_grid = session.reversed_grid()
					grid_order = _race_grid
					reset_race()
					if skip_garage:
						start_race()
					elif garage != null:
						open_garage()
					return
	if session.spectator and _spectator_input():
		return
	_update_progress()
	_update_levels()
	_drive_cars(step)
	if combat.enabled:
		_combat_tick(step)
	session.tick(step)
	if is_two_player():
		_human_safety(step)
	_settle_garage()
	if session.state == RaceSession.State.FINISHED and session.all_finished():
		_conclude_race()
	if session.spectator:
		_spectator_tick(step)
	_update_camera_target(step)
	if net != null:
		net.host_after_tick()


## Grid panel and results controls: the default actions, and in two-player
## races each player's own controller as well.
func _menu_pressed(action: String) -> bool:
	if Input.is_action_just_pressed(action):
		return true
	if is_two_player():
		for n in [1, 2]:
			var a := PlayerControls.player_prefix(n) + action
			if InputMap.has_action(a) and Input.is_action_just_pressed(a):
				return true
	return false


func start_race() -> void:
	if session.state != RaceSession.State.MODE_SELECT:
		return
	races_started += 1
	for id in session.human_ids:
		if id < cars.size():
			cars[id].model.control_mode = player_control_modes.get(id, session.control_mode)
	for id in grid_order:
		cars[id].active = true
		inputs[id].begin_race(race_seed(races_started, id))
	session.start()
	if session.spectator:
		_follow_last_starter()
	_race_open = true
	race_began.emit()
	if net != null:
		net.on_race_started()
	if garage != null and not session.spectator:
		garage.begin_race()
	hud.hide_message()
	hud.flash_banner("GO!", HyperTheme.GOLD, GO_BANNER_HOLD)
	if race_audio != null:
		race_audio.play_cue("race/start_go")
		race_audio.play_music("race")


## Seed of a rival's decisions in a given race (stable across sessions).
func race_seed(race_number: int, racer_id: int) -> int:
	return hash([base_seed, race_number, racer_id])


func _spectator_input() -> bool:
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


## Cars not in this race (the player when spectating, a rival sitting out) are
## hidden, without collision, and parked far away.
func _show_car(id: int, on: bool) -> void:
	var c := cars[id]
	c.visible = on
	_apply_car_collision(id, on)
	if not on:
		c.active = false
		c.place(Transform2D(0.0, Vector2(-100000, -100000)))


## Collision layers for a car's presence and road level. Only touches the
## physics body when they change: re-assigning the same collision layers
## re-registers the body and changes contact order.
func _apply_car_collision(id: int, present: bool) -> void:
	var c := cars[id]
	var want := Track.car_collision(car_levels[id], car_transitions[id] == 1) if present else Vector2i.ZERO
	if c.collision_layer != want.x or c.collision_mask != want.y:
		c.collision_layer = want.x
		c.collision_mask = want.y


## J1: each car's road level from its progress along its own branch; a car
## changes level (and collision layers) only at the ends of an elevation zone,
## which the layout keeps clear of the other road. Flat circuits: nothing.
func _update_levels() -> void:
	if not track.layout.has_elevation():
		return
	for id in grid_order:
		var level := track.level_at_distance(progress[id].distance)
		var band := 1 if track.in_transition(progress[id].distance) else 0
		if level != car_levels[id] or band != car_transitions[id]:
			car_levels[id] = level
			car_transitions[id] = band
			_apply_car_collision(id, true)


## A car's road level as this computer knows it (a network client reads the
## host's progress from the snapshots).
func level_of(id: int) -> int:
	if not track.layout.has_elevation():
		return 0
	if net != null and net.is_client():
		return track.level_at_distance(session.racers[id].progress)
	return car_levels[id]


## The level a car is drawn on: the bridge level while on it and also near
## either bridge end, so a car straddling the deck's edge is drawn whole above
## it (never half under it).
func draw_level_of(id: int) -> int:
	if not track.layout.has_elevation():
		return 0
	var s: float = session.racers[id].progress if net != null and net.is_client() else progress[id].distance
	return 1 if level_of(id) == 1 or track.in_transition(s) else 0


## J2: cars on the bridge draw above the deck, cars below it underneath
## (presentation only; flat circuits: nothing).
func _present_levels() -> void:
	if not track.layout.has_elevation():
		return
	for i in cars.size():
		var z := Track.UPPER_Z_OFFSET * draw_level_of(i)
		if cars[i].z_index != z:
			cars[i].z_index = z


## Esc (any player's Back) during a race opens the race menu.
func _check_race_menu() -> void:
	var racing := session.state == RaceSession.State.RACING or (session.spectator and session.state == RaceSession.State.FINISHED)
	if menu_open or network_lost or not racing:
		return
	if _menu_pressed(PlayerControls.BACK):
		open_race_menu()


## Opens the Esc menu. Single-player, spectator and couch races pause; a
## network race goes on for the other player (this computer's car brakes).
func open_race_menu() -> void:
	if menu_open:
		return
	menu_open = true
	_menu_paused = net == null
	if _menu_paused:
		get_tree().paused = true
	race_menu.open(net != null)


## Back to the same race, exactly where it was.
func resume_race() -> void:
	if not menu_open:
		return
	menu_open = false
	race_menu.close()
	if _menu_paused:
		get_tree().paused = false
		_menu_paused = false


## Leaves the race for the main menu (a network race disconnects; an unfinished
## garage race pays nothing and uses no rounds: see _exit_tree).
func leave_race() -> void:
	resume_race()
	set_sim_speed(1)
	exit_requested.emit()


## Spectator camera: every race starts on the car in the last grid slot.
func _follow_last_starter() -> void:
	spectator_start_grid = grid_order.duplicate()
	if not spectator_start_grid.is_empty():
		director.follow(spectator_start_grid[-1])


## Spectator: follow this driver (clicked in the standings). Presentation only.
func follow_driver(id: int) -> void:
	if session.spectator and session.is_participating(id) and grid_order.has(id):
		director.follow(id)


## Spectator: previous (-1) / next (+1) driver in this race's starting-grid order.
func follow_step(direction: int) -> void:
	if session.spectator:
		follow_driver(SpectatorDirector.grid_neighbour(spectator_start_grid, director.target_id, direction))


func _update_camera_target(step: float = 0.0) -> void:
	if player_views != null:
		camera.target = _park
		camera.position_smoothing_enabled = false
		return
	if not session.spectator:
		camera.target = cars[local_player_id]
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
	if net != null and net.race != null:
		hud.set_net_quality("" if network_lost else net.quality_text(), net.connection_bad())
	if lighting != null and Input.is_action_just_pressed(PlayerControls.TOGGLE_LIGHTING):
		lighting.set_enabled(not lighting.enabled)
	_check_race_menu()
	# the finish banner first, so results shown in the same frame wait for it
	_present_finishers()
	_present_levels()
	_refresh_hud()
	if _listener != null:
		var mid := Vector2.ZERO
		for id in session.human_ids:
			mid += cars[id].global_position
		_listener.global_position = mid / session.human_ids.size()


## Finish celebrations (presentation only): the player's finish in a race, the
## winner's finish when spectating.
func _present_finishers() -> void:
	var count := session.finish_order.size()
	if count <= _seen_finishers:
		_seen_finishers = mini(_seen_finishers, count)
		return
	for k in range(_seen_finishers, count):
		var id: int = session.finish_order[k]
		var human := session.human_ids.has(id) and not session.spectator
		var celebrate := human or (session.spectator and k == 0)
		if celebrate:
			var text := "FINISH!"
			if session.spectator:
				text = "%s WINS!" % RivalRoster.short_name(id).to_upper()
			elif is_two_player():
				text = "%s FINISHED!" % session.racers[id].display_name
			hud.flash_banner(text)
			if effects != null:
				effects.celebrate(track.checkpoint_transform(0).origin)
			if race_audio != null:
				race_audio.play_cue("race/finish")
	_seen_finishers = count


func _refresh_hud() -> void:
	if network_lost:
		return
	hud.set_follow(session.spectator, director.target_id)
	hud.update_tower(session.standings())
	if session.spectator:
		var leader := session.standings()[0] if session.racer_count() > 0 else null
		var following := RivalRoster.short_name(director.target_id) if director.target_id > 0 else "-"
		hud.update_spectator(history.race_count() + (0 if session.state == RaceSession.State.FINISHED else 1),
			leader.tracker.current_lap() if leader != null else 1, session.racers[0].tracker.lap_count,
			session.elapsed, "x%d" % sim_speed, following, weapons_enabled)
		hud.update_combat(false, 0, 0, 0, 0, 0.0)
		return
	if player_views != null:
		var standings := session.standings()
		for v in player_views.views:
			v.hud.set_results_up(session.state == RaceSession.State.FINISHED)
			_refresh_player_hud(v.hud, v.racer_id)
			v.hud.update_tower(standings)
		if session.state == RaceSession.State.FINISHED:
			hud.show_results(session.standings())
		return
	var me := local_player_id
	var p := session.racers[me]
	var time := p.finish_time if p.is_finished() else session.elapsed
	hud.update_race(p.tracker.current_lap(), p.tracker.lap_count, time,
		session.position_of(me), session.racer_count())
	hud.update_combat(weapons_enabled, combat.weapon_of(me, CombatWorld.FRONT), combat.ammo[me][CombatWorld.FRONT],
		combat.weapon_of(me, CombatWorld.REAR), combat.ammo[me][CombatWorld.REAR], combat.wreck_left[me],
		_cooldown_fraction(CombatWorld.FRONT, me), _cooldown_fraction(CombatWorld.REAR, me))
	if session.state == RaceSession.State.FINISHED:
		if net != null:
			hud.show_results(session.standings(), "Fire: next race" if net.is_host() else "Waiting for the host to continue")
		elif garage != null and _garage_settled:
			hud.show_results(session.standings(), "Prize money: $%d     Fire: garage     Tab: skip shopping, next race" % garage.last_prize)
		else:
			hud.show_results(session.standings())


## One human's HUD: their own position, lap, time, weapons and cooldowns.
func _refresh_player_hud(view_hud: Hud, id: int) -> void:
	var r := session.racers[id]
	view_hud.update_race(r.tracker.current_lap(), r.tracker.lap_count, r.finish_time if r.is_finished() else session.elapsed,
		session.position_of(id), session.racer_count())
	view_hud.update_combat(weapons_enabled, combat.weapon_of(id, CombatWorld.FRONT), combat.ammo[id][CombatWorld.FRONT],
		combat.weapon_of(id, CombatWorld.REAR), combat.ammo[id][CombatWorld.REAR], combat.wreck_left[id],
		_cooldown_fraction(CombatWorld.FRONT, id), _cooldown_fraction(CombatWorld.REAR, id))


## 0 = ready, 1 = just fired (a human's slot, for the HUD bar).
func _cooldown_fraction(slot: int, id: int = RaceSession.PLAYER_ID) -> float:
	var length := combat.slot_cooldown_length(slot)
	return clampf(combat.slot_wait(id, slot) / maxf(0.001, length), 0.0, 1.0)


func _update_progress() -> void:
	for id in grid_order:
		progress[id].update(cars[id].global_position)
		session.set_progress(id, progress[id].distance)


## Every car in the race takes its command for this tick from its DriverInput.
func _drive_cars(step: float) -> void:
	for id in grid_order:
		var cmd := inputs[id].drive(self, step)
		cars[id].steer = cmd.steer
		cars[id].fire = cmd.fire


func _on_checkpoint_reached(index: int, body: Node2D) -> void:
	if net != null and net.is_client():
		return  # laps come from the host
	var c := body as Car
	if c == null or not c.active:
		return
	session.checkpoint_reached(index, c.racer_id)


## Combat for one tick: the humans' Up/Down presses and then the rivals'
## decisions become fire requests (same rules for all), then the combat world
## advances; destroyed cars stop where they are, respawned cars carry on.
func _combat_tick(step: float) -> void:
	var states := _combat_states()
	for id in session.human_ids:
		if grid_order.has(id):
			_request_weapons(id, inputs[id].weapons(self, step, states), states)
	if session.state != RaceSession.State.MODE_SELECT:
		for id in grid_order:
			if not inputs[id].is_human():
				_request_weapons(id, inputs[id].weapons(self, step, states), states)
	var result := combat.step(step, states)
	for id in result.destroyed:
		cars[id].active = false
		cars[id].model.velocity = Vector2.ZERO
		inputs[id].on_destroyed()
	for id in result.respawned:
		cars[id].model.velocity = Vector2.ZERO
		if session.state != RaceSession.State.MODE_SELECT:
			cars[id].active = true


func _request_weapons(id: int, cmd: Dictionary, states: Array) -> void:
	if cmd.front:
		combat.request(id, CombatWorld.FRONT, states)
	if cmd.rear:
		combat.request(id, CombatWorld.REAR, states)


func _combat_states() -> Array:
	var states: Array = []
	for i in cars.size():
		states.append({"position": cars[i].global_position, "heading": cars[i].model.heading,
			"present": grid_order.has(i)})
		if combat.layout != null:  # J4: road level for elevation-aware weapons
			states[i]["level"] = car_levels[i]
			states[i]["band"] = car_transitions[i] == 1
			states[i]["index"] = progress[i].index
	return states
