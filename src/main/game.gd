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


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	settings = AudioSettings.new()
	settings.load_settings()
	settings.apply()
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
	title.achievements = achievements
	add_child(title)
	title.setup(resolver, settings)
	title.start_requested.connect(start_race)
	title.two_player_requested.connect(func(devices: Array[int]) -> void: start_race(0, false, devices))
	title.lan_host_requested.connect(func() -> void: host_lan())
	title.lan_join_requested.connect(func(address: String) -> void: join_lan(address))
	title.lan_cancel_requested.connect(close_lan)
	title.quit_requested.connect(quit_game)
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
func start_race(choice: int, with_garage: bool = false, devices: Array[int] = [], net: NetRace = null, net_track: int = -1) -> void:
	if race != null or _starting:
		return  # a race is already running or starting: never create a second one
	_starting = true
	await _fade_to(1.0)
	title.hide_title()
	race = MAIN_SCENE.instantiate()
	race.allow_exit = true
	var two := devices.size() == 2 or net != null
	if net != null:
		race.human_count = 2
		race.net = net
	elif two:
		race.human_count = 2
		race.player_devices = devices
	elif with_garage and choice != 2:
		race.garage = garage
	if not two:
		race.achievements = achievements
	race.track_variant = net_track if net != null and net.is_client() else title.track_variant
	add_child(race)
	race.garage_requested.connect(_open_garage)
	race.camera.make_current()
	race.set_menu_choice(choice)
	if net == null or net.is_host():  # a LAN client takes the host's settings
		race.set_weapons_enabled(title.weapons_on)
		race.set_combat_style(title.combat_style)
		race.set_lap_count(title.laps)
	race.exit_requested.connect(back_to_title)
	if choice == 2:
		race.start_race()  # spectating starts straight away
	elif with_garage:
		race.open_garage()  # shop before the first garage race
	_starting = false
	await _fade_to(0.0)


func _open_garage() -> void:
	garage_screen.open()


func _close_garage(start: bool) -> void:
	garage_screen.close()
	if race != null:
		race.close_garage(start)


func back_to_title() -> void:
	await _fade_to(1.0)
	garage_screen.close()
	close_lan()
	if race != null:
		race.queue_free()
		race = null
	title.show_title()
	await _fade_to(0.0)


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
	link.send([NetRace.Msg.WELCOME, NetRace.PROTOCOL, NetRace.GAME_BUILD, {"track_variant": title.track_variant}], true, peer_id)
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
		if not NetRace.valid(msg, [TYPE_INT, TYPE_STRING]) or msg[1] != NetRace.PROTOCOL or msg[2] != NetRace.GAME_BUILD:
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
					or msg[2] != NetRace.GAME_BUILD:
				close_lan()
				title.lan_panel.set_busy(false)
				title.lan_panel.show_status("The host runs a different version of HyperCars (both computers need the same build).", true)
				return
			if race == null and not _starting:
				link.send([NetRace.Msg.HELLO, NetRace.PROTOCOL, NetRace.GAME_BUILD], true)
				var track: int = clampi(int(msg[3].get("track_variant", 1)), 1, TrackTheme.VARIANT_COUNT)
				start_race(0, false, [], NetRace.new(link, NetRace.Role.CLIENT), track)
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
