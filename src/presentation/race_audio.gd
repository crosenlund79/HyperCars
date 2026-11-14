class_name RaceAudio
extends Node
## Race soundscape: one engine voice per car (pitch follows speed, louder on
## throttle), tyre squeal from sliding, impact sounds, race start and finish
## cues, trackside ambience and menu/race music. Read-only: it observes car
## state and hit signals and never changes the race.

const ENGINE_MIN_PITCH := 0.7
const ENGINE_MAX_PITCH := 2.6
const SLIDE_SQUEAL := 80.0
const MAX_DISTANCE := 1600.0

var _cars: Array[Car] = []
var _engines: Array[AudioStreamPlayer2D] = []
var _squeals: Array[AudioStreamPlayer2D] = []
var _impacts: Array[AudioStreamPlayer2D] = []
var _next_impact := 0
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _cue: AudioStreamPlayer
var _resolver: AssetResolver
var _music_name := ""
## Own generator: presentation never touches the global or race random state.
var _rng := RandomNumberGenerator.new()
## Fast simulation: engines and squeal are turned down (sounds are not sped up).
var fast := false


func setup(cars: Array[Car], resolver: AssetResolver, sound_parent: Node2D) -> void:
	AudioSettings.ensure_buses()
	_cars = cars
	_resolver = resolver
	var engine := resolver.get_audio("vehicles/engine_loop", true)
	var squeal := resolver.get_audio("vehicles/tire_squeal", true)
	for i in cars.size():
		_engines.append(_player2d(sound_parent, engine, "Engine", -6.0))
		_squeals.append(_player2d(sound_parent, squeal, "Effects", -80.0))
	for k in 10:
		_impacts.append(_player2d(sound_parent, null, "Effects", 0.0))
	for c in cars:
		c.wall_hit.connect(func(_n: Vector2, speed: float) -> void: _impact(c, speed, "vehicles/impact_wall"))
		c.car_hit.connect(func(_o: Car, speed: float) -> void: _impact(c, speed, "vehicles/impact_car"))
	_music = _player(resolver, "", "Music", -4.0)
	_ambience = _player(resolver, "ambience/ambience", "Effects", -10.0)
	_cue = _player(resolver, "", "Effects", -2.0)
	_ambience.play()


## "menu" or "race".
func play_music(mood: String) -> void:
	var logical := "music/music_" + mood
	if logical == _music_name and _music.playing:
		return
	_music_name = logical
	_music.stream = _resolver.get_audio(logical, true)
	_music.play()


func play_cue(logical: String) -> void:
	_cue.stream = _resolver.get_audio(logical)
	_cue.play()


func _process(_delta: float) -> void:
	for i in _cars.size():
		var c := _cars[i]
		var engine := _engines[i]
		var squeal := _squeals[i]
		var running := c.visible and c.model != null and (c.active or c.model.velocity.length() > 1.0)
		if not running or fast:
			if engine.playing and (not c.visible or fast):
				engine.stop()
			if squeal.playing:
				squeal.stop()
			if not running or not c.visible:
				continue
		if fast:
			continue
		engine.global_position = c.global_position
		squeal.global_position = c.global_position
		var speed := absf(c.model.forward_speed())
		var ratio := clampf(speed / c.model.params.max_speed, 0.0, 1.2)
		engine.pitch_scale = lerpf(ENGINE_MIN_PITCH, ENGINE_MAX_PITCH, ratio)
		var throttle := c.active and c.model.is_accelerating(c.fire)
		engine.volume_db = lerpf(-14.0, -5.0, ratio) + (1.5 if throttle else -2.0)
		if not engine.playing:
			engine.play(_rng.randf() * 0.9)
		var slide := absf(c.model.lateral_speed())
		if c.active and slide > SLIDE_SQUEAL:
			squeal.volume_db = lerpf(-20.0, -6.0, clampf((slide - SLIDE_SQUEAL) / 220.0, 0.0, 1.0))
			squeal.pitch_scale = 0.9 + clampf(speed / 600.0, 0.0, 0.3)
			if not squeal.playing:
				squeal.play()
		elif squeal.playing:
			squeal.stop()


## Stop everything on exit so no playback outlives the scene.
func _exit_tree() -> void:
	for p in _engines + _squeals + _impacts:
		p.stop()
		p.stream = null
	for p in [_music, _ambience, _cue]:
		if p != null:
			p.stop()
			p.stream = null


## One-shot positional sound (weapons); skipped in fast simulation.
func play_at(logical: String, pos: Vector2) -> void:
	if fast:
		return
	var p := _impacts[_next_impact]
	_next_impact = (_next_impact + 1) % _impacts.size()
	p.stream = _resolver.get_audio(logical)
	p.global_position = pos
	p.volume_db = -2.0
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.play()


func stop_cars() -> void:
	for p in _engines + _squeals:
		p.stop()


func _impact(c: Car, speed: float, logical: String) -> void:
	if fast or speed < 60.0 or not c.visible:
		return
	var p := _impacts[_next_impact]
	_next_impact = (_next_impact + 1) % _impacts.size()
	p.stream = _resolver.get_audio(logical)
	p.global_position = c.global_position
	p.volume_db = lerpf(-14.0, 0.0, clampf(speed / 400.0, 0.0, 1.0))
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.play()


func _player2d(parent: Node2D, stream: AudioStream, bus: String, volume: float) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume
	p.max_distance = MAX_DISTANCE
	p.attenuation = 1.6
	parent.add_child(p)
	return p


func _player(resolver: AssetResolver, logical: String, bus: String, volume: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if not logical.is_empty():
		p.stream = resolver.get_audio(logical, AssetCatalog.AUDIO[logical].loop)
	p.bus = bus
	p.volume_db = volume
	add_child(p)
	return p
