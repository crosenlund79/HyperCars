class_name CombatView
extends Node2D
## Combat presentation: draws missiles, blinking mines and explosions from the
## CombatWorld state, darkens and smokes wrecked cars, plays weapon sounds.
## Read-only: it reads the combat state and its append-only event log through
## its own cursor, and never changes combat, cars or the race.

const W := WeaponRules.Weapon
const TEXTURES := {W.HOMING_MISSILE: AssetCatalog.HOMING_MISSILE, W.SUPER_MISSILE: AssetCatalog.SUPER_MISSILE}
const LAUNCH_SOUNDS := {W.MINE: "weapons/mine_drop", W.HOMING_MISSILE: "weapons/homing_launch",
	W.SUPER_MISSILE: "weapons/super_launch"}

var enabled := true
## Racer ids whose empty-weapon clicks are heard (the humans).
var human_ids: Array[int] = [RaceSession.PLAYER_ID]
var _combat: CombatWorld
var _cars: Array[Car] = []
var _resolver: AssetResolver
var _audio: RaceAudio
var _missiles: Array[Sprite2D] = []
var _mines: Array[Sprite2D] = []
var _smoke: Array[CPUParticles2D] = []
var _cursor := 0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(combat: CombatWorld, cars: Array[Car], resolver: AssetResolver, audio: RaceAudio) -> void:
	_combat = combat
	_cars = cars
	_resolver = resolver
	_audio = audio
	z_index = 3
	for c in cars:
		var p := CPUParticles2D.new()
		p.texture = resolver.get_texture(AssetCatalog.SMOKE)
		p.amount = 14
		p.lifetime = 1.4
		p.local_coords = false
		p.emitting = false
		p.direction = Vector2.UP
		p.spread = 35.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 50.0
		p.color = Color(0.25, 0.22, 0.2, 0.8)
		var fade := Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade
		p.scale_amount_min = 0.8
		p.scale_amount_max = 1.6
		add_child(p)
		_smoke.append(p)


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if not on:
		for p in _smoke:
			p.emitting = false
		_cursor = _combat.events.size()


func _process(delta: float) -> void:
	_time += delta
	if not enabled or _combat == null:
		return
	if _cursor > _combat.events.size():
		_cursor = 0  # combat was reset for a new race
	while _cursor < _combat.events.size():
		_show_event(_combat.events[_cursor])
		_cursor += 1
	_sync_missiles()
	_sync_mines()
	for i in _cars.size():
		var wrecked := _combat.enabled and _combat.is_wrecked(i) and _cars[i].visible
		_cars[i].modulate = Color(0.35, 0.32, 0.3) if wrecked else (Color(1, 1, 1, 0.6 + 0.4 * absf(sin(_time * 12.0)))
			if _combat.enabled and _combat.grace_left[i] > 0.0 else Color.WHITE)
		_smoke[i].global_position = _cars[i].global_position
		_smoke[i].emitting = wrecked


func _sync_missiles() -> void:
	while _missiles.size() < _combat.projectiles.size():
		var s := Sprite2D.new()
		add_child(s)
		_missiles.append(s)
	for i in _missiles.size():
		var on := i < _combat.projectiles.size()
		_missiles[i].visible = on
		if on:
			var p: Dictionary = _combat.projectiles[i]
			var logical: String = TEXTURES.get(p.type, AssetCatalog.MISSILE)
			var tex := _resolver.get_texture(logical)
			if _missiles[i].texture != tex:
				_missiles[i].texture = tex
				_missiles[i].scale = AssetCatalog.scale_for(tex, AssetCatalog.SPECS[logical].display_size)
			_missiles[i].position = p.pos
			_missiles[i].rotation = (p.angle + PI * 0.5) if p.type == W.SUPER_MISSILE else p.dir.angle()


func _sync_mines() -> void:
	var tex := _resolver.get_texture(AssetCatalog.MINE)
	while _mines.size() < _combat.mines.size():
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = AssetCatalog.SPECS[AssetCatalog.MINE].frames
		var frame := Vector2(tex.get_width() / float(s.hframes), tex.get_height())
		s.scale = AssetCatalog.SPECS[AssetCatalog.MINE].display_size / frame
		s.z_index = -2
		add_child(s)
		_mines.append(s)
	for i in _mines.size():
		var on := i < _combat.mines.size()
		_mines[i].visible = on
		if on:
			var m: Dictionary = _combat.mines[i]
			_mines[i].position = m.pos
			var fast_blink: bool = m.age > _combat.rules.mine_fuse - 1.0
			_mines[i].frame = int(m.age * (8.0 if fast_blink else 3.0)) % 2


func _show_event(e: Dictionary) -> void:
	match e.kind:
		"fire":
			_play(LAUNCH_SOUNDS.get(e.type, "weapons/missile_launch"), e.pos)
		"empty":
			if human_ids.has(e.car):
				_play("weapons/empty", e.pos)
		"explode", "mine_blast":
			_blast(e.pos, 1.4 if e.kind == "mine_blast" else 0.8)
			_play("weapons/explosion", e.pos)
		"destroyed":
			_blast(_cars[e.car].global_position, 1.2)


func _blast(pos: Vector2, size: float) -> void:
	var s := Sprite2D.new()
	s.texture = _resolver.get_texture(AssetCatalog.BLAST)
	var base := AssetCatalog.scale_for(s.texture, AssetCatalog.SPECS[AssetCatalog.BLAST].display_size) * size
	s.position = pos
	s.rotation = _rng.randf_range(0, TAU)
	s.scale = base * 0.4
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", base, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.5).set_delay(0.12)
	tw.chain().tween_callback(s.queue_free)


func _play(logical: String, pos: Vector2) -> void:
	if _audio != null:
		_audio.play_at(logical, pos)
