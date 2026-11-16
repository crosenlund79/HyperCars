class_name Track
extends Node2D
## Builds one circuit from a TrackLayout: ground, road surface, barrier walls
## (visual + collision), start/finish line and invisible checkpoint gates.

signal checkpoint_reached(index: int, body: Node2D)

const WALL_LAYER := 1
const CAR_LAYER := 2
## J1 (elevated layouts only): barriers of the elevated road and cars on it
## use their own collision layers, so the two levels never touch.
const WALL_UPPER_LAYER := 4
const CAR_UPPER_LAYER := 8
## J2 draw order on elevated layouts: everything on the bridge level draws
## UPPER_Z_OFFSET above its ground-level counterpart (cars 0 -> 6, mines 1 -> 7,
## missiles 3 -> 9); the bridge's shadow and deck sit in between.
const UPPER_Z_OFFSET := 6
const BRIDGE_SHADOW_Z := 4
const BRIDGE_DECK_Z := 5
## Shadow of the deck at full height (px, light from the top left), and the
## share of each zone at either end over which the bridge rises / falls.
const BRIDGE_SHADOW_OFFSET := Vector2(18, 26)
const BRIDGE_RAMP_SHARE := 0.3
const BRIDGE_SHADOW_COLOR := Color(0.05, 0.04, 0.08, 0.36)
const CHECKPOINT_DEPTH := 30.0
const GROUND_MARGIN := 900.0

@export var layout: TrackLayout
## Visual theme variant (ground, road, barrier). Geometry and collision are
## the same for every variant. Null = Variant 1.
var theme: TrackTheme

var centerline := PackedVector2Array()
var checkpoint_samples := PackedInt32Array()
## Centreline as a measurable path (race progress, AI navigation).
var path: ClosedPath


func build(resolver: AssetResolver, p_theme: TrackTheme = null) -> void:
	theme = p_theme if p_theme != null else TrackTheme.load_variant(1)
	for child in get_children():
		child.free()
	centerline = layout.sample_centerline()
	path = ClosedPath.new(centerline)
	checkpoint_samples = layout.checkpoint_sample_indices(centerline.size(), centerline)
	var half := layout.road_width * 0.5
	var left_edge := TrackLayout.offset_line(centerline, -half)
	var right_edge := TrackLayout.offset_line(centerline, half)
	_build_ground(resolver.get_texture(theme.asset(AssetCatalog.GRASS)))
	_build_road(resolver.get_texture(theme.asset(AssetCatalog.TARMAC)), left_edge, right_edge)
	_build_start_line(resolver.get_texture(theme.asset(AssetCatalog.START_LINE)))
	_build_walls(resolver.get_texture(theme.asset(AssetCatalog.WALL)), half, left_edge, right_edge)
	if layout.has_elevation():
		_build_bridge_shadow(half + AssetCatalog.SPECS[theme.asset(AssetCatalog.WALL)].display_size.y)
	_build_checkpoints()


func checkpoint_count() -> int:
	return checkpoint_samples.size()


## Centre point and driving direction of checkpoint gate i.
func checkpoint_transform(index: int) -> Transform2D:
	var s := checkpoint_samples[index]
	var tan := TrackLayout.tangents(centerline)[s]
	return Transform2D(tan.angle(), centerline[s])


## Starting grid slot (0 = pole) behind the start/finish line, facing along the track.
func grid_transform(slot: int) -> Transform2D:
	var g := layout.grid_slot(slot)
	var s: float = path.length - g.behind
	var tan := path.tangent_at(s)
	var right := Vector2(-tan.y, tan.x)
	return Transform2D(tan.angle(), path.point_at(s) + right * g.lateral)


func _build_ground(texture: Texture2D) -> void:
	var bounds := Rect2(centerline[0], Vector2.ZERO)
	for p in centerline:
		bounds = bounds.expand(p)
	bounds = bounds.grow(GROUND_MARGIN)
	var corners := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end,
		Vector2(bounds.position.x, bounds.end.y)])
	var poly := _textured_polygon("Ground", texture, corners, AssetCatalog.SPECS[theme.asset(AssetCatalog.GRASS)].tile_world_size)
	add_child(poly)


func _build_road(texture: Texture2D, left_edge: PackedVector2Array, right_edge: PackedVector2Array) -> void:
	var n := left_edge.size()
	var verts := PackedVector2Array(left_edge)
	verts.append_array(right_edge)
	var poly := _textured_polygon("Road", texture, verts, AssetCatalog.SPECS[theme.asset(AssetCatalog.TARMAC)].tile_world_size)
	var quads: Array = []
	var deck_quads: Array = []
	for i in n:
		var j := (i + 1) % n
		var quad := PackedInt32Array([i, j, n + j, n + i])
		if layout.has_elevation() and level_of_sample(i) == 1:
			deck_quads.append(quad)
		else:
			quads.append(quad)
	poly.polygons = quads
	add_child(poly)
	if not deck_quads.is_empty():
		# J2: the elevated road is its own surface above the ground level
		var deck := _textured_polygon("BridgeDeck", texture, verts, AssetCatalog.SPECS[theme.asset(AssetCatalog.TARMAC)].tile_world_size)
		deck.polygons = deck_quads
		deck.z_index = BRIDGE_DECK_Z
		add_child(deck)


func _textured_polygon(node_name: String, texture: Texture2D, verts: PackedVector2Array, tile_world: float) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = node_name
	poly.polygon = verts
	poly.texture = texture
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var uv_scale := AssetCatalog.uv_per_world_pixel(texture, tile_world)
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(v * uv_scale)
	poly.uv = uvs
	return poly


func _build_walls(texture: Texture2D, half: float, left_edge: PackedVector2Array, right_edge: PackedVector2Array) -> void:
	var wall_spec: Dictionary = AssetCatalog.SPECS[theme.asset(AssetCatalog.WALL)]
	var wall_width: float = wall_spec.display_size.y
	if layout.has_elevation():
		_build_level_walls(left_edge, right_edge)
	else:
		var body := StaticBody2D.new()
		body.name = "Walls"
		body.collision_layer = WALL_LAYER
		body.collision_mask = 0
		add_child(body)
		for edge in [left_edge, right_edge]:
			var segments := PackedVector2Array()
			for i in edge.size():
				segments.append(edge[i])
				segments.append(edge[(i + 1) % edge.size()])
			var shape := ConcavePolygonShape2D.new()
			shape.segments = segments
			var cs := CollisionShape2D.new()
			cs.shape = shape
			body.add_child(cs)
	# Visual barriers sit just outside the collision faces so the car meets their inner edge.
	for side in [-1.0, 1.0]:
		var points := TrackLayout.offset_line(centerline, side * (half + wall_width * 0.5))
		var line_name := "Barrier%s" % ("Left" if side < 0 else "Right")
		if not layout.has_elevation():
			add_child(_barrier_line(line_name, points, true, wall_width, texture))
			continue
		# J2: one open line per run of road on one level; bridge railings above the deck
		for run in _level_runs():
			var pts := PackedVector2Array()
			for k in range(run.from, run.to + 1):  # one shared point joins the runs
				pts.append(points[k % points.size()])
			var line := _barrier_line("%s%s%d" % [line_name, "Upper" if run.level == 1 else "", run.from], pts, false, wall_width, texture)
			if run.level == 1:
				line.z_index = BRIDGE_DECK_Z
			add_child(line)


## Elevated layouts: each barrier segment belongs to the level of its stretch
## of road ("Walls" ground, "WallsUpper" bridge), so a car only meets the
## barriers of its own level where the roads cross.
func _build_level_walls(left_edge: PackedVector2Array, right_edge: PackedVector2Array) -> void:
	var segments := [PackedVector2Array(), PackedVector2Array()]
	for edge in [left_edge, right_edge]:
		for i in edge.size():
			var level := level_of_sample(i)
			segments[level].append(edge[i])
			segments[level].append(edge[(i + 1) % edge.size()])
	for level in 2:
		var body := StaticBody2D.new()
		body.name = "Walls" if level == 0 else "WallsUpper"
		body.collision_layer = WALL_LAYER if level == 0 else WALL_UPPER_LAYER
		body.collision_mask = 0
		add_child(body)
		var shape := ConcavePolygonShape2D.new()
		shape.segments = segments[level]
		var cs := CollisionShape2D.new()
		cs.shape = shape
		body.add_child(cs)


## Road level of centreline sample i (0 ground, 1 elevated).
func level_of_sample(i: int) -> int:
	return layout.level_at(path.cumulative[i], path.length)


## Road level at a car's progress (arc distance along its branch).
func level_at_distance(s: float) -> int:
	return layout.level_at(s, path.length)


## Road level at a car's progress is changing (near a zone end, both levels).
func in_transition(s: float) -> bool:
	return layout.in_transition(s, path.length)


## Collision layer / mask of a present car on a road level; in a transition
## band (near a bridge end) it belongs to both levels.
static func car_collision(level: int, transition: bool = false) -> Vector2i:
	if transition:
		return Vector2i(CAR_LAYER | CAR_UPPER_LAYER, WALL_LAYER | WALL_UPPER_LAYER | CAR_LAYER | CAR_UPPER_LAYER)
	if level == 0:
		return Vector2i(CAR_LAYER, WALL_LAYER | CAR_LAYER)
	return Vector2i(CAR_UPPER_LAYER, WALL_UPPER_LAYER | CAR_UPPER_LAYER)


func _barrier_line(line_name: String, points: PackedVector2Array, closed: bool, width: float, texture: Texture2D) -> Line2D:
	var line := Line2D.new()
	line.name = line_name
	line.points = points
	line.closed = closed
	line.width = width
	line.texture = texture
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	return line


## Consecutive centreline sample runs on one level: [{level, from, to}] with
## unwrapped sample indices (use index % size); `to` is the first sample of the
## next run, so neighbouring runs share one point and join seamlessly.
func _level_runs() -> Array:
	var n := centerline.size()
	var start := -1
	for i in n:
		if level_of_sample(i) != level_of_sample((i - 1 + n) % n):
			start = i
			break
	if start < 0:
		return [{"level": level_of_sample(0), "from": 0, "to": n}]
	var runs: Array = []
	var from := start
	for k in range(1, n + 1):
		var i := start + k
		if k == n or level_of_sample(i % n) != level_of_sample(from % n):
			runs.append({"level": level_of_sample(from % n), "from": from, "to": i})
			from = i
	return runs


## How high the road is at arc distance s (0 ground .. 1 full bridge height):
## the bridge rises over the first and falls over the last part of its zone.
func bridge_height(s: float) -> float:
	var w := fposmod(s, path.length)
	for z in layout.elevation_zones:
		if w >= z.x and w < z.y:
			var ramp := (z.y - z.x) * BRIDGE_RAMP_SHARE
			return smoothstep(0.0, 1.0, minf(w - z.x, z.y - w) / ramp)
	return 0.0


## Soft shadow of the deck and its railings on the ground below, offset by the
## bridge's height (none where it meets the ground). Procedural, no artwork.
func _build_bridge_shadow(half_outer: float) -> void:
	var tans := TrackLayout.tangents(centerline)
	for run in _level_runs():
		if run.level != 1:
			continue
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for k in range(run.from, run.to + 1):
			var i := k % centerline.size()
			var lift := BRIDGE_SHADOW_OFFSET * bridge_height(path.cumulative[i])
			var r := Vector2(-tans[i].y, tans[i].x)
			left.append(centerline[i] - r * half_outer + lift)
			right.append(centerline[i] + r * half_outer + lift)
		right.reverse()
		var shadow := Polygon2D.new()
		shadow.name = "BridgeShadow%d" % run.from
		shadow.polygon = left + right
		shadow.color = BRIDGE_SHADOW_COLOR
		shadow.z_index = BRIDGE_SHADOW_Z
		add_child(shadow)


func _build_start_line(texture: Texture2D) -> void:
	var t := checkpoint_transform(0)
	var sprite := Sprite2D.new()
	sprite.name = "StartLine"
	sprite.texture = texture
	sprite.position = t.origin
	sprite.rotation = t.get_rotation()
	var display := Vector2(AssetCatalog.SPECS[theme.asset(AssetCatalog.START_LINE)].display_size.x, layout.road_width)
	sprite.scale = AssetCatalog.scale_for(texture, display)
	add_child(sprite)


func _build_checkpoints() -> void:
	for c in checkpoint_samples.size():
		var t := checkpoint_transform(c)
		var area := Area2D.new()
		area.name = "Checkpoint%d" % c
		area.collision_layer = 0
		area.collision_mask = CAR_LAYER
		area.monitorable = false
		area.position = t.origin
		area.rotation = t.get_rotation()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(CHECKPOINT_DEPTH, layout.road_width + 40.0)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		area.add_child(cs)
		area.body_entered.connect(func(body: Node2D) -> void: checkpoint_reached.emit(c, body))
		add_child(area)
