class_name DamageView
extends Node2D
## M6 presentation of vehicle condition (read-only; existing smoke / spark
## textures and sounds only): a car in critical condition trails grey smoke, a
## retired car (DNF) is a darkened, smoking wreck with a crash and sparks,
## until it is taken off the road. Reads DamageWorld; never changes the race.
## Runs after CombatView (added later), so a retired wreck stays dark.

const RETIRED_TINT := Color(0.3, 0.27, 0.26)

var enabled := true
var _damage: DamageWorld
var _cars: Array[Car] = []
var _resolver: AssetResolver
var _audio: RaceAudio
var _smoke: Array[CPUParticles2D] = []
var _was_retired := PackedByteArray()
var _tinted := PackedByteArray()


func setup(damage: DamageWorld, cars: Array[Car], resolver: AssetResolver, audio: RaceAudio) -> void:
	_damage = damage
	_cars = cars
	_resolver = resolver
	_audio = audio
	_was_retired.resize(cars.size())
	_tinted.resize(cars.size())
	for c in cars:
		var p := CPUParticles2D.new()
		p.texture = resolver.get_texture(AssetCatalog.SMOKE)
		p.amount = 14
		p.lifetime = 1.1
		p.local_coords = false
		p.emitting = false
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 24.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0.8))
		fade.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = fade
		add_child(p)
		_smoke.append(p)


func _process(_delta: float) -> void:
	for i in _cars.size():
		var c := _cars[i]
		var retired := _damage.is_retired(i)
		var critical := _damage.is_critical(i)
		var smoke := _smoke[i]
		smoke.global_position = c.global_position
		smoke.z_index = c.z_index + 1
		smoke.emitting = enabled and c.visible and (retired or critical)
		smoke.color = Color(0.16, 0.14, 0.14) if retired else Color(0.55, 0.53, 0.52)
		smoke.amount = 14
		if retired and c.visible:
			c.modulate = RETIRED_TINT
			_tinted[i] = 1
		elif _tinted[i] == 1:
			c.modulate = Color.WHITE
			_tinted[i] = 0
		if retired and _was_retired[i] == 0 and c.visible:
			_burst(c)
			if _audio != null:
				_audio.play_at("weapons/explosion", c.global_position)
		_was_retired[i] = 1 if retired else 0


func _burst(c: Car) -> void:
	if not enabled:
		return
	var p := CPUParticles2D.new()
	p.texture = _resolver.get_texture(AssetCatalog.SPARK)
	p.amount = 18
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.color = Color(1, 0.8, 0.5)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 190.0
	p.global_position = c.global_position
	p.z_index = c.z_index + 2
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
