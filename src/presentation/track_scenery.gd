class_name TrackScenery
extends Node2D
## Decorative trackside scenery and road decals. Visual only: no collision
## shapes, no physics, its own random generator (never the race seeds), and it
## only reads the track's geometry. Ambient animation: trees sway, flags wave.
## The props and every asset follow the track's theme variant (TrackTheme).

const SEED := 4242
## Minimum distance from any decoration's centre to the barrier face (px).
const CLEARANCE := 70.0

var _sway: Array[Sprite2D] = []
var _flags: Array[Sprite2D] = []
var _time := 0.0
var _theme: TrackTheme


## decals go on the road under the cars; props sit on the grass.
func build(track: Track, resolver: AssetResolver, decal_layer: Node2D) -> void:
	_theme = track.theme if track.theme != null else TrackTheme.load_variant(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var c := track.centerline
	var half := track.layout.road_width * 0.5
	var tans := TrackLayout.tangents(c)
	var n := c.size()
	# Grid boxes on the start grid.
	for slot in 10:
		var g := track.grid_transform(slot)
		_sprite(decal_layer, resolver, AssetCatalog.GRID_BOX, g.origin + Vector2.from_angle(g.get_rotation()) * 4.0, g.get_rotation(), Color(1, 1, 1, 0.75))
	# Road wear where the track turns most (corner apexes).
	var curvature := PackedFloat32Array()
	for i in n:
		curvature.append(absf(tans[i].angle_to(tans[(i + 6) % n])))
	for i in n:
		if curvature[i] > 0.35 and i % 7 == 0:
			var side := signf(tans[i].cross(tans[(i + 6) % n]))
			var right := Vector2(-tans[i].y, tans[i].x)
			_sprite(decal_layer, resolver, AssetCatalog.ROAD_WEAR, c[i] + right * side * half * 0.35, tans[i].angle(), Color(1, 1, 1, 0.55))
	# Grandstands along the main straight, on the outside, crowd facing the track.
	var start_dir := tans[0]
	var start_out := -Vector2(-start_dir.y, start_dir.x)  # outside of a clockwise lap = left
	for k in [-2, -1, 0, 1, 2]:
		var s := fposmod(k * 320.0 + 160.0, track.path.length)
		var p := track.path.point_at(s) + start_out * (half + 150.0)
		if _clear_of_track(p, c, half + 90.0):
			var st := _sprite(self, resolver, AssetCatalog.GRANDSTAND, p, start_dir.angle())
			st.z_index = 1
	# Props scattered around the circuit, clear of the barriers.
	var kinds := []
	for k in _theme.scenery.size():
		kinds.append([_theme.scenery[k], _theme.scenery_weights[k], _theme.scenery_sway[k]])
	var placed := 0
	var attempts := 0
	while placed < 140 and attempts < 2000:
		attempts += 1
		var i := rng.randi_range(0, n - 1)
		var right := Vector2(-tans[i].y, tans[i].x)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := c[i] + right * side * (half + rng.randf_range(CLEARANCE + 30.0, 520.0)) + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
		if not _clear_of_track(p, c, half + CLEARANCE + 30.0):
			continue
		var kind: Array = _pick(kinds, rng)
		var spr := _sprite(self, resolver, kind[0], p, rng.randf_range(0, TAU))
		var scale_jitter := rng.randf_range(0.8, 1.2)
		spr.scale *= scale_jitter
		spr.z_index = 2 if kind[2] else 0
		if kind[2]:
			spr.set_meta("phase", rng.randf_range(0, TAU))
			spr.set_meta("base_rot", spr.rotation)
			_sway.append(spr)
		placed += 1
	# Tyre stacks and waving flags on the outside of the corners.
	for i in n:
		if curvature[i] > 0.45 and i % 11 == 0:
			var side := signf(tans[i].cross(tans[(i + 6) % n]))
			var right := Vector2(-tans[i].y, tans[i].x)
			var outside := -right * side
			var p := c[i] + outside * (half + 60.0)
			if _clear_of_track(p, c, half + 45.0):
				_sprite(self, resolver, AssetCatalog.TYRE_STACK, p, rng.randf_range(0, TAU))
				var fp := p + tans[i] * 50.0 + outside * 10.0
				if _clear_of_track(fp, c, half + 45.0):
					_flags.append(_flag(resolver, fp))


func _process(delta: float) -> void:
	_time += delta
	for s in _sway:
		s.rotation = s.get_meta("base_rot") + sin(_time * 0.9 + s.get_meta("phase")) * 0.035
	var frame := int(_time * 4.0) % 2
	for f in _flags:
		f.frame = (frame + int(f.get_meta("offset"))) % 2


func sway_count() -> int:
	return _sway.size()


func flag_count() -> int:
	return _flags.size()


static func _clear_of_track(p: Vector2, centerline: PackedVector2Array, min_distance: float) -> bool:
	var d2 := min_distance * min_distance
	for q in centerline:
		if p.distance_squared_to(q) < d2:
			return false
	return true


static func _pick(kinds: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0.0
	for k in kinds:
		total += k[1]
	var r := rng.randf() * total
	for k in kinds:
		r -= k[1]
		if r <= 0.0:
			return k
	return kinds[0]


func _sprite(parent: Node, resolver: AssetResolver, shared_logical: String, pos: Vector2, rot: float, tint: Color = Color.WHITE) -> Sprite2D:
	var logical := _theme.asset(shared_logical)
	var spr := Sprite2D.new()
	spr.texture = resolver.get_texture(logical)
	spr.position = pos
	spr.rotation = rot
	spr.modulate = tint
	spr.scale = AssetCatalog.scale_for(spr.texture, AssetCatalog.SPECS[logical].display_size)
	parent.add_child(spr)
	return spr


func _flag(resolver: AssetResolver, pos: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	var logical := _theme.asset(AssetCatalog.FLAG)
	spr.texture = resolver.get_texture(logical)
	spr.hframes = AssetCatalog.SPECS[logical].frames
	spr.position = pos
	var frame_size := Vector2(spr.texture.get_width() / float(spr.hframes), spr.texture.get_height())
	spr.scale = AssetCatalog.SPECS[logical].display_size / frame_size
	spr.offset = Vector2(0, -frame_size.y * 0.4)
	spr.z_index = 2
	spr.set_meta("offset", _flags.size() % 2)
	add_child(spr)
	return spr
