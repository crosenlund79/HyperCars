class_name LightingPilot
extends Node2D
## Night racing (TIME: NIGHT; started as the lighting pilot). A night presentation:
## the world is tinted darker, ten trackside lamps light the road, each car
## carries one light (a soft headlight cone plus a small glow so the car stays
## readable), and weapon explosions flash briefly. Toggle with L.
## Presentation only: reads car transforms and the combat event log; no physics,
## no collision, no gameplay writes. The HUD is on its own canvas layer and is
## not darkened.

const AMBIENT := Color(0.42, 0.44, 0.58)
const LAMP_COLOR := Color(1.0, 0.86, 0.6)
const HEADLIGHT_COLOR := Color(1.0, 0.95, 0.82)
const LAMP_COUNT := 10
const FLASHES := 4

var enabled := false
var _ambient: CanvasModulate
var _lamps: Array[PointLight2D] = []
var _lamp_sprites: Array[Sprite2D] = []
var _car_lights: Array[PointLight2D] = []
## J2 (elevated layouts): road level of a racer; a car's light only lights its own level.
var level_of: Callable
var _flashes: Array[PointLight2D] = []
var _flash_age := PackedFloat32Array()
var _next_flash := 0
var _cars: Array[Car] = []
var _combat: CombatWorld
var _cursor := 0


var lamp_color := LAMP_COLOR
var lamp_energy := 1.15
var lamp_count := LAMP_COUNT
var headlight_energy := 0.95


## theme: the biome's night mood (ambient tint, lamps, headlights); null = the pilot's.
func setup(track: Track, cars: Array[Car], combat: CombatWorld, resolver: AssetResolver, theme: TrackTheme = null) -> void:
	_cars = cars
	_combat = combat
	var ambient := AMBIENT
	if theme != null:
		ambient = theme.night_ambient
		lamp_color = theme.lamp_color
		lamp_energy = theme.lamp_energy
		lamp_count = theme.lamp_count
		headlight_energy = theme.headlight_energy
	_ambient = CanvasModulate.new()
	_ambient.color = ambient
	add_child(_ambient)
	var radial := _radial_texture(256)
	_light_texture = radial
	if track != null:  # (the Battle Royale arena places its own lamps: add_lamp)
		_place_lamps(track, resolver, radial)
	var car_tex := _car_light_texture()
	for c in cars:
		var l := PointLight2D.new()
		l.texture = car_tex
		l.color = HEADLIGHT_COLOR
		l.energy = headlight_energy
		l.texture_scale = 1.0
		l.offset = Vector2(car_tex.get_width() * 0.5 - 40.0, 0)
		add_child(l)
		_car_lights.append(l)
	for k in FLASHES:
		var f := PointLight2D.new()
		f.texture = radial
		f.color = Color(1.0, 0.7, 0.35)
		f.texture_scale = 1.3
		f.energy = 0.0
		add_child(f)
		_flashes.append(f)
	_flash_age.resize(FLASHES)
	_flash_age.fill(1.0)
	set_enabled(false)


func set_enabled(on: bool) -> void:
	enabled = on
	_ambient.visible = on
	for l in _lamps + _car_lights + _flashes:
		l.enabled = on
	for s in _lamp_sprites:
		s.visible = on
	if _combat != null:
		_cursor = _combat.events.size()


func light_count() -> int:
	return _lamps.size() + _car_lights.size() + _flashes.size()


func _process(delta: float) -> void:
	if not enabled:
		return
	for i in _cars.size():
		var c := _cars[i]
		var l := _car_lights[i]
		l.enabled = c.visible
		l.global_position = c.global_position
		l.global_rotation = c.global_rotation
		if level_of.is_valid():
			var upper: bool = level_of.call(c.racer_id) == 1
			l.range_z_min = Track.BRIDGE_DECK_Z if upper else RenderingServer.CANVAS_ITEM_Z_MIN
			l.range_z_max = RenderingServer.CANVAS_ITEM_Z_MAX if upper else Track.BRIDGE_SHADOW_Z - 1
	if _combat != null:
		if _cursor > _combat.events.size():
			_cursor = 0
		while _cursor < _combat.events.size():
			var e: Dictionary = _combat.events[_cursor]
			_cursor += 1
			if e.kind == "explode" or e.kind == "mine_blast":
				var f := _flashes[_next_flash]
				f.global_position = e.pos
				_flash_age[_next_flash] = 0.0
				_next_flash = (_next_flash + 1) % FLASHES
	for k in FLASHES:
		_flash_age[k] = minf(1.0, _flash_age[k] + delta / 0.45)
		_flashes[k].energy = 1.6 * (1.0 - _flash_age[k])


## The environment's lamps (ten by default): on the outside of the sharpest corners and along the main straight.
func _place_lamps(track: Track, resolver: AssetResolver, tex: Texture2D) -> void:
	var c := track.centerline
	var n := c.size()
	var tans := TrackLayout.tangents(c)
	var half := track.layout.road_width * 0.5
	var spots: Array = []
	for i in range(0, n, 3):
		spots.append([absf(tans[i].angle_to(tans[(i + 6) % n])), i])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var chosen: Array[int] = [0]
	for s in spots:
		if chosen.size() >= lamp_count:
			break
		var ok := true
		for j in chosen:
			if c[j].distance_to(c[s[1]]) < 500.0:
				ok = false
		if ok:
			chosen.append(s[1])
	var lamp_tex := resolver.get_texture(AssetCatalog.LAMP_POST)
	for i in chosen:
		var right := Vector2(-tans[i].y, tans[i].x)
		var turn := signf(tans[i].cross(tans[(i + 6) % n]))
		var outside := -right * (turn if turn != 0.0 else 1.0)
		var pos := c[i] + outside * (half + 34.0)
		if track.layout.has_elevation() and not _clear_of_roads(pos, c, half + 20.0):
			continue  # J2: never on the other road of a crossing layout
		add_lamp(pos, outside, lamp_tex, tex)


var _light_texture: Texture2D


## One lamp post at pos, its light thrown towards -outside (the arena uses this).
func add_lamp(pos: Vector2, outside: Vector2, lamp_tex: Texture2D, tex: Texture2D = null) -> void:
	if tex == null:
		tex = _light_texture
	var spr := Sprite2D.new()
	spr.texture = lamp_tex
	spr.scale = AssetCatalog.scale_for(lamp_tex, AssetCatalog.SPECS[AssetCatalog.LAMP_POST].display_size)
	spr.position = pos
	spr.rotation = (-outside).angle() + PI * 0.5
	spr.z_index = 2
	add_child(spr)
	_lamp_sprites.append(spr)
	var l := PointLight2D.new()
	l.texture = tex
	l.color = lamp_color
	l.energy = lamp_energy
	l.texture_scale = 2.2
	l.position = pos - outside * 40.0
	l.enabled = enabled
	spr.visible = enabled
	add_child(l)
	_lamps.append(l)


static func _clear_of_roads(pos: Vector2, c: PackedVector2Array, min_distance: float) -> bool:
	for p in c:
		if p.distance_to(pos) < min_distance:
			return false
	return true


static func _radial_texture(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


## One light per car: a soft cone ahead (+X) plus a small glow round the car.
static func _car_light_texture() -> ImageTexture:
	var w := 320
	var h := 200
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var origin := Vector2(40, h * 0.5)
	for y in h:
		for x in w:
			var p := Vector2(x, y) - origin
			var glow := clampf(1.0 - p.length() / 46.0, 0.0, 1.0) * 0.55
			var cone := 0.0
			if p.x > 18.0:
				var ang := absf(atan2(p.y, p.x))
				var spread := clampf(1.0 - ang / deg_to_rad(24.0), 0.0, 1.0)
				var falloff := clampf(1.0 - (p.x - 18.0) / 270.0, 0.0, 1.0)
				cone = spread * spread * falloff * 0.9
			var a := clampf(glow + cone, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
