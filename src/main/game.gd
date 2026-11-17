extends Node
## Game root (run/main_scene): owns the title screen and starts the race scene
## (src/main/main.tscn) as a child with the chosen mode, fading between them.
## Loads and applies the saved audio settings. The race scene itself is
## unchanged and still runs on its own (tests use it directly).
## Garage races (M3.5): one PlayerGarage lives for the whole game session (money
## and weapons carry over between garage races until the game quits); the
## garage screen opens before the first garage race and after each one.

const MAIN_SCENE := preload("res://src/main/main.tscn")

## Where achievements and rival careers are saved (tests use a scratch file).
@export var achievements_path := AchievementStore.DEFAULT_PATH
## Where the won rival cars are saved (tests use a scratch file).
@export var cars_path := CarCollection.DEFAULT_PATH

var resolver: AssetResolver
var settings: AudioSettings
var title: TitleScreen
var race: Node2D
var _fade: ColorRect
var garage: PlayerGarage
## True while a race scene is being started (guards against a second start).
var _starting := false
## LAN races (M5.1): the connection, kept from the title into the race scene.
var link: NetLink
var lan_port := NetLink.DEFAULT_PORT
## Host: the peer that connected and must say HELLO (matching version) in time.
var _pending_peer := 0
## Client: when connecting started (ms) and to where, for the progress message.
var _connect_started := -1
var _connect_target := ""
const HELLO_TIMEOUT := 8.0
var garage_screen: GarageScreen
## Achievements (M3.5): one persistent store for the installation, the toast.
var achievements: AchievementStore
var toast: AchievementToast
## The music for the whole session (menus and races hand it over, no restarts).
var music: MusicPlayer
## Championship: the won rival cars (saved), the running championship (null
## outside one), its screen, the player's control choice for its rounds, and
## the last reward (rival id, -1 none) for tests.
var cars: CarCollection
var champ: Championship
var champ_screen: ChampionshipScreen
var _champ_choice := 0
var last_reward := -1
## Racing for Keeps: the won car lost in the last championship (0 none), for tests.
var last_lost := 0
var reward_rng := RandomNumberGenerator.new()


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	settings = AudioSettings.new()
	settings.load_settings()
	settings.apply()
	ControlBindings.load_saved()  # the player's remapped controls (CONTROLS screen)
	resolver = AssetResolver.new()
	achievements = AchievementStore.new(achievements_path)
	achievements.load_store()
	toast = AchievementToast.new()
	toast.name = "AchievementToast"
	add_child(toast)
	toast.setup(resolver)
	achievements.unlocked.connect(toast.show_unlock)
	title = TitleScreen.new()
	title.name = "Title"
	music = MusicPlayer.new()
	music.name = "Music"
	add_child(music)
	music.resolver = resolver
	title.music = music
	title.achievements = achievements
	cars = CarCollection.new(cars_path)
	title.cars = cars
	title.championship = ChampionshipSchedule.for_run(cars.championships_run)
	add_child(title)
	title.setup(resolver, settings)
	if cars.forfeited_on_load > 0:  # the game was closed during a championship for keeps
		title.show_notice(lost_text(cars.forfeited_on_load, true))
	title.start_requested.connect(start_race)
	title.two_player_requested.connect(func(devices: Array[int]) -> void: start_race(0, false, devices))
	title.lan_host_requested.connect(func() -> void: host_lan())
	title.lan_join_requested.connect(func(address: String) -> void: join_lan(address))
	title.lan_cancel_requested.connect(close_lan)
	title.quit_requested.connect(quit_game)
	title.championship_requested.connect(start_championship)
	title.mode_requested.connect(func(mode: String, choice: int) -> void:
		if mode == "battle":
			start_battle(choice)
		else:
			start_race(choice, false, [], null, -1, "", false, {}, mode))
	champ_screen = ChampionshipScreen.new()
	champ_screen.name = "ChampionshipScreen"
	add_child(champ_screen)
	champ_screen.setup(resolver)
	champ_screen.continue_requested.connect(_next_round)
	champ_screen.abandon_requested.connect(abandon_championship)
	champ_screen.done.connect(abandon_championship)
	reward_rng.randomize()
	garage = PlayerGarage.new(load("res://src/garage/default_garage_rules.tres"))
	garage_screen = GarageScreen.new()
	garage_screen.name = "Garage"
	add_child(garage_screen)
	garage_screen.setup(garage, resolver)
	garage_screen.race_requested.connect(func() -> void: _close_garage(true))
	garage_screen.closed.connect(func() -> void: _close_garage(false))
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("1c1614")
	_fade.size = Vector2(1280, 720)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	await _fade_to(0.0)


## choice: 0 Fire to Accelerate, 1 Fire to Brake, 2 Spectate rivals.
## with_garage: a garage race (money and the player's own weapons).
## devices: two-player split-screen with these controllers (no garage or
## achievements in two-player races).
## net: a LAN race (NetRace host or client); net_track: the host's track (client).
## net_night: the host's time of day (client). round: a championship round
## (Championship.next_round(); empty = not a championship race).
func start_race(choice: int, with_garage: bool = false, devices: Array[int] = [], net: NetRace = null, net_track: int = -1,
		net_layout: String = "", net_night: bool = false, round: Dictionary = {}, mode: String = "race") -> void:
	if race != null or _starting:
		return  # a race is already running or starting: never create a second one
	_starting = true
	PlayerControls.set_race_context(true)  # Fire never presses a button from here on
	await _fade_to(1.0)
	title.hide_title()
	race = MAIN_SCENE.instantiate()
	race.allow_exit = true
	race.music = music
	var two := devices.size() == 2 or net != null
	if net != null:
		race.human_count = 2
		race.net = net
	elif two:
		race.human_count = 2
		race.player_devices = devices
	elif with_garage and choice != 2:
		race.garage = garage
	if not two and mode == "race":  # (Knockout is not counted for achievements)
		race.achievements = achievements
	race.race_mode = mode
	race.watch_enabled = true  # finished early: watch the rest live (single-player only)
	var client := net != null and net.is_client()
	race.track_variant = net_track if client else title.track_variant
	race.night = net_night if client else title.night
	# the title's LAYOUT choice (a LAN / online client: the host's layout)
	race.use_command_line_layout = false
	race.layout_override = DevLayouts.load_layout(net_layout if client else title.layout_id)
	if not two:  # won rival cars (single-player and spectating only)
		race.player_car = title.player_car if cars.owns(title.player_car) else CarCollection.OWN_CAR
		race.displaced = cars.owned.duplicate()
	if not round.is_empty():
		race.track_variant = round.variant
		race.night = round.night
		race.layout_override = DevLayouts.load_layout(round.layout)
		race.championship_round = champ.round_index()
		race.championship_grid = champ.next_grid()
		race.championship_points = champ.points.duplicate()
		race.championship_scoring = champ.schedule.points
		race.championship_label = ("GRAND FINAL  -  ROUND %d OF %d" if round.get("final", false) else "ROUND %d OF %d") % [champ.round_index() + 1, champ.schedule.round_count()]
		if cars.stake > 0:
			race.championship_label += "  -  FOR KEEPS: %s'S CAR" % RivalRoster.short_name(cars.stake).to_upper()
			race.forfeit_warning = "Leaving forfeits the championship: %s takes the car back." % RivalRoster.short_name(cars.stake)
	add_child(race)
	race.garage_requested.connect(_open_garage)
	race.camera.make_current()
	race.set_menu_choice(choice)
	if net == null or net.is_host():  # a LAN client takes the host's settings
		race.set_weapons_enabled(title.weapons_on)
		race.set_combat_style(title.combat_style)
		race.set_lap_count(title.laps if round.is_empty() else int(round.laps))
		if mode == "knockout":
			race.set_lap_count(race.cars.size() - 1)  # one elimination per lap until one is left
	race.exit_requested.connect(back_to_title)
	if not round.is_empty():
		race.championship_round_done.connect(_on_round_done)
	if choice == 2:
		race.start_race()  # spectating starts straight away
	elif with_garage:
		race.open_garage()  # shop before the first garage race
	_starting = false
	await _fade_to(0.0)


func _open_garage() -> void:
	garage_screen.open()
	music.play("music/music_menu")


func _close_garage(start: bool) -> void:
	garage_screen.close()
	if race != null:
		race.close_garage(start)


func back_to_title() -> void:
	await _fade_to(1.0)
	garage_screen.close()
	champ_screen.close()
	_forfeit_championship()
	champ = null  # leaving a championship round abandons the championship
	close_lan()
	if race != null:
		race.queue_free()
		race = null
	title.show_title()
	await _fade_to(0.0)


# -------------------------------------------------------------- Battle Royale

## GO RACING! > BATTLE ROYALE: the arena with the title's biome, time and car.
func start_battle(choice: int) -> void:
	if race != null or _starting:
		return
	_starting = true
	PlayerControls.set_race_context(true)
	await _fade_to(1.0)
	title.hide_title()
	var b := BattleRoyale.new()
	b.name = "BattleRoyale"
	b.track_variant = title.track_variant
	b.night = title.night
	b.player_car = title.player_car if cars.owns(title.player_car) else CarCollection.OWN_CAR
	b.displaced = cars.owned.duplicate()
	b.music = music
	b.base_seed = reward_rng.randi()
	race = b
	add_child(b)
	if choice == 1:
		b.cars[0].model.control_mode = CarModel.ControlMode.FIRE_TO_BRAKE
	b.exit_requested.connect(back_to_title)
	b.restart_requested.connect(func() -> void: _restart_battle(choice))
	_starting = false
	await _fade_to(0.0)


func _restart_battle(choice: int) -> void:
	if race != null:
		race.queue_free()
		race = null
	start_battle(choice)


# ---------------------------------------------------------------- Championship

## Starts a championship (six rounds, or the three-round version) with the title's next schedule.
func start_championship(choice: int) -> void:
	if race != null or _starting or champ != null:
		return
	champ = Championship.new(title.championship.with_length(title.championship_rounds))
	_champ_choice = choice
	last_reward = -1
	last_lost = 0
	cars.put_at_stake(title.player_car)  # Racing for Keeps (the own car is never at stake)
	cars.count_championship()
	title.championship = ChampionshipSchedule.for_run(cars.championships_run)  # the one after this
	start_race(choice, false, [], null, -1, "", false, champ.next_round())


## A round's result (Enter on the results): record it and show the standings.
func _on_round_done(order: Array, dnf: Array) -> void:
	if champ == null or race == null:
		return
	champ.record(order, dnf)
	await _fade_to(1.0)
	var player_car: int = race.player_car
	race.queue_free()
	race = null
	champ_screen.set_icons(car_icons(player_car))
	music.play("music/music_menu")
	var reward := ""
	var reward_car: Texture2D = null
	if champ.finished():
		if champ.champion() == Championship.PLAYER:
			cars.clear_stake()  # the car entered with stays
			last_reward = cars.unlock_random(reward_rng)
			reward = reward_text(last_reward, cars.all_owned())
			if last_reward > 0:
				reward_car = CarArt.icon(resolver, AssetCatalog.ai_car(last_reward))
		elif cars.stake > 0:
			last_lost = cars.stake
			cars.lose(last_lost)
			reward = lost_text(last_lost)
			reward_car = CarArt.icon(resolver, AssetCatalog.ai_car(last_lost))
		else:
			reward = "Win the championship to take one of your rivals' cars."
		title.refresh_car_choice()
	champ_screen.warning = "FOR KEEPS: abandoning gives %s's car back." % RivalRoster.short_name(cars.stake) \
		if cars.stake > 0 and not champ.finished() else ""
	champ_screen.show_standings(champ, reward, reward_car)
	await _fade_to(0.0)


## The reward message for a won championship (rival -1: nothing left to win).
static func reward_text(rival: int, all_owned: bool) -> String:
	if rival < 1:
		return "CHAMPIONSHIP WON!\nYou already own all nine rival cars - the collection is complete."
	var text := "CHAMPIONSHIP WON - YOU UNLOCKED %s!\n%s's car is yours, in its original colours. %s races a junker from now on." % [
		RivalRoster.nickname(rival).to_upper(), RivalRoster.short_name(rival), RivalRoster.short_name(rival)]
	if all_owned:
		text += "\nALL NINE RIVAL CARS COLLECTED!"
	return text


## Racing for Keeps: the result when the car at stake goes back.
static func lost_text(rival: int, forfeit: bool = false) -> String:
	return "%s\n%s RECLAIMS THE CAR!\nWin it back in a later championship." % [
		"CHAMPIONSHIP FORFEITED" if forfeit else "CHAMPIONSHIP LOST", RivalRoster.short_name(rival).to_upper()]


## Car pictures for the standings, as the cars race (junkers, the player's car).
func car_icons(player_car: int) -> Dictionary:
	var icons := {}
	icons[RaceSession.PLAYER_ID] = CarArt.icon(resolver, AssetCatalog.ai_car(player_car)) \
		if player_car > 0 else CarArt.icon(resolver, AssetCatalog.CAR_PLAYER)
	for id in range(1, 10):
		icons[id] = CarArt.icon(resolver, AssetCatalog.CAR_JUNKER if cars.displaced(id) else AssetCatalog.ai_car(id))
	return icons


func _next_round() -> void:
	if champ == null or champ.finished() or race != null or _starting:
		return
	champ_screen.close()
	start_race(_champ_choice, false, [], null, -1, "", false, champ.next_round())


## Abandon (or, after the final, finish) the championship: back to the menu.
## Abandoning an unfinished championship for keeps forfeits the car at stake
## (the screens ask for confirmation first).
func abandon_championship() -> void:
	if race != null:
		return
	back_to_title()


## Leaving an unfinished championship: a car at stake goes back to its rival.
func _forfeit_championship() -> void:
	if champ == null or champ.finished():
		return
	if cars.stake > 0:
		last_lost = cars.stake
		cars.lose(last_lost)
		title.refresh_car_choice()
		title.show_notice(lost_text(last_lost, true))
	cars.clear_stake()


# ---------------------------------------------------------------- LAN (M5.1)

func _lan_link() -> NetLink:
	if link == null:
		link = NetLink.new()
		link.name = "NetLink"
		add_child(link)
		link.peer_joined.connect(_on_lan_peer_joined)
		link.connected.connect(func() -> void: title.lan_panel.show_status("Connected. Getting the race ready..."))
		link.connection_failed.connect(func() -> void:
			_connect_started = -1
			title.lan_panel.set_busy(false)
			title.lan_panel.show_status("Could not connect to %s. Check the address, that the host is waiting, and (over the internet) the host's port forwarding and firewall - see docs/NETWORK_PLAY.md." % _connect_target, true))
		link.server_closed.connect(func() -> void:
			if race == null:
				title.lan_panel.set_busy(false)
				title.lan_panel.show_status("The host closed the game.", true))
		link.message.connect(_on_lan_message)
		link.peer_left.connect(func(id: int) -> void:
			if race == null and id == _pending_peer:
				_pending_peer = 0
				title.lan_panel.show_status("The other player left before the race. Still waiting for a player..."))
	return link


## Hosts a LAN race and waits for the other player (title status shows the address).
func host_lan() -> Error:
	if (link != null and link.is_open()) or race != null or _starting:
		return ERR_ALREADY_IN_USE  # already hosting / joining / racing: repeated presses change nothing
	var err := _lan_link().host(lan_port)
	if err != OK:
		title.lan_panel.show_status("Could not host on port %d (error %d). Is another game already hosting on this computer?" % [lan_port, err], true)
		return err
	title.lan_panel.set_busy(true)
	title.lan_panel.show_status("Hosting on UDP port %d. Local network address: %s. Over the internet, give your friend your public IP address (port forwarding needed - see docs/NETWORK_PLAY.md). Waiting for the other player..." % [lan_port, ", ".join(local_addresses())])
	return OK


## Joins the race hosted at `address`: an IPv4 address on this computer, the
## local network or the internet, optionally with ":port" (default 24680).
func join_lan(address: String) -> Error:
	if (link != null and link.is_open()) or race != null or _starting:
		return ERR_ALREADY_IN_USE
	var a := NetLink.parse_address(address, lan_port)
	if not a.ok:
		title.lan_panel.show_status(a.error, true)
		return ERR_INVALID_PARAMETER
	var err := _lan_link().join(a.ip, a.port)
	if err != OK:
		title.lan_panel.show_status("Could not start connecting (error %d)." % err, true)
		return err
	title.lan_panel.set_busy(true)
	_connect_started = Time.get_ticks_msec()
	_connect_target = "%s:%d" % [a.ip, a.port]
	title.lan_panel.show_status("Connecting to %s..." % _connect_target)
	return OK


## Connection progress on the title while a join is pending.
func _process(_delta: float) -> void:
	if _connect_started >= 0 and link != null and link.is_open() and race == null:
		var s := (Time.get_ticks_msec() - _connect_started) / 1000
		if link.peers().is_empty():
			title.lan_panel.show_status("Connecting to %s... %d s (Cancel to stop)" % [_connect_target, s])
	elif _connect_started >= 0 and race != null:
		_connect_started = -1


func close_lan() -> void:
	_pending_peer = 0
	_connect_started = -1
	if link != null:
		link.close()


## This computer's IPv4 LAN addresses (shown to the host).
static func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.is_valid_ip_address() and not ":" in a and not a.begins_with("127."):
			out.append(a)
	if out.is_empty():
		out.append("127.0.0.1")
	return out


## Host: a computer connected. It gets WELCOME (version + the host's track)
## and must answer HELLO with the same version within HELLO_TIMEOUT seconds;
## only then does the session start. Anyone joining a race in progress (or a
## second visitor while one is being greeted) is refused.
func _on_lan_peer_joined(peer_id: int) -> void:
	if race != null or _starting or _pending_peer != 0:
		_refuse(peer_id, "busy")
		return
	_pending_peer = peer_id
	link.send([NetRace.Msg.WELCOME, NetRace.PROTOCOL, NetRace.build_id(), {"track_variant": title.track_variant,
		"layout": title.layout_id, "night": title.night}], true, peer_id)
	title.lan_panel.show_status("Player connected - checking versions...")
	get_tree().create_timer(HELLO_TIMEOUT, true, false, true).timeout.connect(_hello_timeout.bind(peer_id))


func _hello_timeout(peer_id: int) -> void:
	if _pending_peer == peer_id and race == null and link != null:
		_pending_peer = 0
		link.disconnect_peer(peer_id)
		title.lan_panel.show_status("The other computer did not answer. Still waiting for a player...")


## Tells a peer why it cannot join, then disconnects it shortly after (so the
## message arrives first).
func _refuse(peer_id: int, reason: String) -> void:
	link.send([NetRace.Msg.REJECT, reason], true, peer_id)
	get_tree().create_timer(0.5, true, false, true).timeout.connect(link.disconnect_peer.bind(peer_id))


func _on_lan_message(from: int, msg: Array) -> void:
	if typeof(msg[0]) != TYPE_INT:
		return
	if link.is_host:
		if msg[0] != NetRace.Msg.HELLO or from != _pending_peer or race != null:
			return
		if not NetRace.valid(msg, [TYPE_INT, TYPE_STRING]) or msg[1] != NetRace.PROTOCOL or msg[2] != NetRace.build_id():
			_pending_peer = 0
			_refuse(from, "version")
			title.lan_panel.show_status("A player with a different version of HyperCars tried to join. Still waiting...")
			return
		_pending_peer = 0
		start_race(0, false, [], NetRace.new(link, NetRace.Role.HOST))
		return
	if from != 1:
		return
	match msg[0]:
		NetRace.Msg.WELCOME:
			if not NetRace.valid(msg, [TYPE_INT, TYPE_STRING, TYPE_DICTIONARY]) or msg[1] != NetRace.PROTOCOL \
					or msg[2] != NetRace.build_id():
				close_lan()
				title.lan_panel.set_busy(false)
				title.lan_panel.show_status("The host runs a different version of HyperCars (both computers need the same build).", true)
				return
			if race == null and not _starting:
				link.send([NetRace.Msg.HELLO, NetRace.PROTOCOL, NetRace.build_id()], true)
				var track: int = clampi(int(msg[3].get("track_variant", 1)), 1, TrackTheme.VARIANT_COUNT)
				var layout := str(msg[3].get("layout", DevLayouts.CLASSIC))
				if not DevLayouts.NAMES.has(layout):
					layout = DevLayouts.CLASSIC  # unknown: never guess a circuit
				start_race(0, false, [], NetRace.new(link, NetRace.Role.CLIENT), track, layout,
					msg[3].get("night", false) == true)
		NetRace.Msg.REJECT:
			var why: String = str(msg[1]) if msg.size() > 1 else ""
			close_lan()
			title.lan_panel.set_busy(false)
			title.lan_panel.show_status("The host runs a different version of HyperCars." if why == "version"
				else "The host is already racing. Try again when their race is over.", true)


func quit_game() -> void:
	await _fade_to(1.0)
	_shutdown()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()


## Stops audio a few frames before quitting so no stream playback outlives the
## scene (Godot otherwise reports it at exit).
func _shutdown() -> void:
	title.stop_audio()
	if race != null:
		race.queue_free()
		race = null
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()


func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, 0.25)
	await tw.finished
	_fade.visible = alpha > 0.0
