class_name CircuitPreview
extends Control
## A small rotating diorama of a circuit for the race setup screen: a
## low-poly plate in the environment's colours with the real centreline on it,
## bridges lifted on pillars, the jump's gap left open, the start line and a
## few faceted trees. Procedural 2.5D (tilted projection, custom drawing); no
## 3D scene, no artwork. Rebuilt whenever the circuit, environment or time changes.

const TILT := 0.5
const LIFT := 16.0
const PLATE_SIDES := 18
const SPIN := 0.22  # rad/s

## Environment palettes (variant -> colours): plate top, plate side, road, barrier, trees.
const PALETTES := {
	1: {"top": Color("6f9a52"), "side": Color("46623a"), "road": Color("707177"), "edge": Color("c84a3a"), "tree": Color("3f7a3a"), "tip": Color("5d9a4f")},
	2: {"top": Color("86724f"), "side": Color("5a4b35"), "road": Color("5b5e68"), "edge": Color("bfae92"), "tree": Color("7a4f6f"), "tip": Color("a2709a")},
	3: {"top": Color("e6edf5"), "side": Color("9fb0c6"), "road": Color("6d7684"), "edge": Color("3a64a8"), "tree": Color("2f5d4a"), "tip": Color("f4f8ff")},
	4: {"top": Color("5f9a4e"), "side": Color("3c5f34"), "road": Color("4a4c54"), "edge": Color("d8423a"), "edge2": Color("f2efe8"), "tree": Color("8a8f9a"), "tip": Color("f6f4dc"), "props": "flood"},
	5: {"top": Color("b47c48"), "side": Color("7a5030"), "road": Color("5e6380"), "edge": Color("e8c068"), "tree": Color("f4c234"), "tip": Color("e88c9c"), "props": "desk"},
}

var angle := 0.0
var layout: TrackLayout
var variant := 1
var night := false
var _pts := PackedVector2Array()   # centred, scaled centreline (decimated)
var _lift := PackedFloat32Array()  # 0..1 height per point
var _gap := PackedByteArray()       # 1 = in a flyover jump's gap (no road)
var _trees := PackedVector2Array()
var _radius := 1.0
## Fits the plate into the control (set each frame from its size).
var _zoom := 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(420, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_circuit(p_layout: TrackLayout, p_variant: int, p_night: bool) -> void:
	layout = p_layout
	variant = clampi(p_variant, 1, PALETTES.size())
	night = p_night
	var c := layout.sample_centerline()
	var path := ClosedPath.new(c)
	var bounds := Rect2(c[0], Vector2.ZERO)
	for p in c:
		bounds = bounds.expand(p)
	var centre := bounds.get_center()
	var scale_k := 300.0 / maxf(bounds.size.x, bounds.size.y)
	_pts.clear()
	_lift.clear()
	_gap.clear()
	_radius = 0.0
	for i in range(0, c.size(), 3):
		var q := (c[i] - centre) * scale_k
		_pts.append(q)
		_radius = maxf(_radius, q.length())
		var s := path.cumulative[i]
		var h := 0.0
		for z in layout.elevation_zones:
			if s >= z.x and s < z.y:
				var ramp := (z.y - z.x) * 0.3
				h = smoothstep(0.0, 1.0, minf(s - z.x, z.y - s) / ramp)
		_lift.append(h)
		var in_gap := 0
		for k in layout.jumps.size():
			var j := layout.jumps[k]
			if s > j.x and s < j.x + j.z and layout.is_flyover(k, path.length):
				in_gap = 1
		_gap.append(in_gap)
	_radius += 26.0
	_trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(layout.resource_path) + variant
	var tries := 0
	while _trees.size() < 14 and tries < 400:
		tries += 1
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.2, 0.93) * _radius
		var clear := true
		for q in _pts:
			if q.distance_to(p) < 22.0:
				clear = false
				break
		if clear:
			_trees.append(p)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or layout == null:
		return
	angle = fposmod(angle + delta * SPIN, TAU)
	queue_redraw()


func _project(p: Vector2, h: float = 0.0) -> Vector2:
	var r := p.rotated(angle) * _zoom
	return size * 0.5 + Vector2(0, 6) + Vector2(r.x, r.y * TILT) - Vector2(0, h * LIFT * _zoom)


func _shade(c: Color) -> Color:
	return c.darkened(0.55).lerp(Color(0.25, 0.32, 0.6), 0.25) if night else c


func _draw() -> void:
	if layout == null:
		return
	var pal: Dictionary = PALETTES[variant]
	_zoom = minf(size.x * 0.94 / (2.0 * _radius), (size.y - 40.0) / (2.0 * _radius * TILT + 20.0))
	var w := clampf(_zoom, 1.0, 1.8)  # line widths grow a little with the plate
	# the plate: a low-poly disc with a visible side
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for k in PLATE_SIDES:
		var p := Vector2.from_angle(TAU * k / PLATE_SIDES) * _radius
		top.append(_project(p))
		bottom.append(_project(p) + Vector2(0, 14 * w))
	for k in PLATE_SIDES:
		var a := top[k]
		var b := top[(k + 1) % PLATE_SIDES]
		if (a.y + b.y) * 0.5 > size.y * 0.5 - 2.0:  # front faces only
			draw_colored_polygon(PackedVector2Array([a, b, bottom[(k + 1) % PLATE_SIDES], bottom[k]]), _shade(pal.side))
	draw_colored_polygon(top, _shade(pal.top))
	# road on the ground, then the raised parts (bridges) with pillars
	var n := _pts.size()
	for pass_index in 2:
		for i in n:
			var j := (i + 1) % n
			if _gap[i] == 1 or _gap[j] == 1:
				continue
			var raised := _lift[i] > 0.05 or _lift[j] > 0.05
			if raised != (pass_index == 1):
				continue
			var a := _project(_pts[i], _lift[i])
			var b := _project(_pts[j], _lift[j])
			if raised and i % 2 == 0 and _lift[i] > 0.5:
				draw_line(_project(_pts[i]), a, _shade(pal.side), 3.0 * w)
			draw_line(a + Vector2(0, 2 * w), b + Vector2(0, 2 * w), _shade(pal.side), 9.0 * w)
			var edge: Color = pal.edge if not pal.has("edge2") or (i / 2) % 2 == 0 else pal.edge2
			draw_line(a, b, _shade(edge), 9.0 * w)
			draw_line(a, b, _shade(pal.road), 6.0 * w)
	# the jump's gap edges and the start line
	for i in n:
		if _gap[i] == 1 and _gap[(i - 1 + n) % n] == 0:
			draw_circle(_project(_pts[i], _lift[i]), 4.0, Color("f0c040"))
	draw_circle(_project(_pts[0]), 3.5, Color.WHITE)
	# faceted trees (drawn back to front)
	var order := Array(_trees)
	order.sort_custom(func(a: Vector2, b: Vector2) -> bool: return _project(a).y < _project(b).y)
	var props: String = pal.get("props", "trees")
	for k in order.size():
		var p: Vector2 = order[k]
		var base := _project(p)
		if props == "flood":  # floodlight masts with a bright lamp bank
			draw_line(base, base - Vector2(0, 22 * w), _shade(pal.tree), 2.0 * w)
			draw_rect(Rect2(base - Vector2(5 * w, 26 * w), Vector2(10 * w, 5 * w)), _shade(pal.tip))
			continue
		if props == "desk":  # giant pencils and dice
			if k % 2 == 0:
				var d := Vector2(14, -4) * w
				draw_line(base - d, base + d, _shade(Color("7a5030")), 7.0 * w)
				draw_line(base - d, base + d, _shade(pal.tree), 5.0 * w)
				draw_circle(base + d, 2.6 * w, _shade(pal.tip))
			else:
				draw_rect(Rect2(base - Vector2(5, 10) * w, Vector2(10, 10) * w), _shade(Color("f6f4ec")))
				draw_rect(Rect2(base - Vector2(5, 10) * w, Vector2(10, 10) * w), _shade(Color("3a3440")), false, 1.0)
				draw_circle(base - Vector2(0, 5) * w, 1.3 * w, _shade(Color("3a3440")))
			continue
		var tip := base - Vector2(0, 16 * w)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6 * w, 0), tip, base + Vector2(6 * w, 0)]), _shade(pal.tree))
		draw_colored_polygon(PackedVector2Array([base, tip, base + Vector2(6 * w, 0)]), _shade(pal.tree).darkened(0.25))
		draw_circle(tip + Vector2(0, 2 * w), 1.6 * w, _shade(pal.tip))
	if night:  # a few lamps along the road (cool floodlights on The Raceway)
		var lamp := Color(0.9, 0.95, 1.0) if variant == 4 else Color(1.0, 0.82, 0.45)
		for i in range(0, n, maxi(1, n / (12 if variant == 4 else 7))):
			draw_circle(_project(_pts[i], _lift[i]) + Vector2(0, -3), 2.4, lamp)
			draw_circle(_project(_pts[i], _lift[i]) + Vector2(0, -3), 6.0, Color(lamp, 0.18))
