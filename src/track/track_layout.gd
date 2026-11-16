class_name TrackLayout
extends Resource
## Data for one closed circuit built from straights and circular corners:
## each control point is a corner whose radius is given in corner_radii, and the
## centreline runs straight between corners. Sampling is pure (no scene), so
## geometry and checkpoints can be unit-tested.

## Corner points of the closed centreline (where straights would meet), in driving order.
@export var control_points: PackedVector2Array
## Centreline radius of the corner at each control point (px). Large = sweeping, small = tight.
@export var corner_radii: PackedFloat32Array
## Drivable width between the barrier faces (px). PROVISIONAL (original: ~3 cars wide).
@export var road_width := 150.0
## Maximum distance between centreline samples (px).
@export var sample_spacing := 20.0
## Number of checkpoints including the start/finish line (checkpoint 0).
@export var checkpoint_count := 12
## Laps per race. PROVISIONAL: the original's lap count per track is unverified.
@export var lap_count := 3
## Starting grid: two staggered columns behind the start/finish line.
## Formation and spacing are PROVISIONAL (the original's grid layout is unverified).
## Distance of the pole position behind the line (px).
@export var grid_first_offset := 60.0
## Distance between grid rows (px).
@export var grid_row_spacing := 80.0
## Lateral distance of each column from the centreline (px).
@export var grid_column_offset := 37.0
## Extra distance the second column starts behind the first (px).
@export var grid_stagger := 40.0
## Optional (J0, experimental): elevated stretches of road (level 1, a bridge),
## each an arc-length interval Vector2(start, end) in px along the sampled
## centreline from the start/finish line, in driving direction. Where the
## centreline crosses itself one branch must be elevated. Empty (every normal
## circuit) = a flat circuit, unchanged behaviour.
@export var elevation_zones: PackedVector2Array = PackedVector2Array()

## Optional (J3, experimental): jumps, each Vector3(lip, ramp_length, gap_length)
## in px along the centreline: a ramp rises over ramp_length up to the lip at
## arc distance `lip`; the gap_length after it has no road (a pit) and must be
## flown over. Empty (every normal circuit) = no jumps.
@export var jumps: PackedVector3Array = PackedVector3Array()

## Room beyond the road edge (px) that crossings, zone ends, checkpoint gates
## and the grid keep from the other road (barrier + a car length + margin).
const CROSSING_CLEARANCE := 120.0
## Gates keep at least this far (px along the road) from a zone end.
const GATE_ZONE_MARGIN := 120.0
## A jump needs this much straight road before its ramp (to line up) and after
## its gap (to land and recover), and keeps gates this far away (px).
const JUMP_RUNWAY := 200.0
## Within this distance (px along the road) of a zone end a car belongs to both
## levels (collides with cars and barriers of either), so two cars on the same
## road are never on different levels while they touch. Must stay below
## GATE_ZONE_MARGIN; zone ends are validated to be far from the other road.
const TRANSITION_BAND := 80.0


## Grid slot (0 = pole) as {distance_behind_line, lateral}; lateral > 0 = right.
func grid_slot(slot: int) -> Dictionary:
	var row := slot / 2
	var column := slot % 2
	return {
		"behind": grid_first_offset + row * grid_row_spacing + column * grid_stagger,
		"lateral": grid_column_offset * (-1.0 if column == 0 else 1.0),
	}


## Problems that make the layout unbuildable (empty when valid).
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var n := control_points.size()
	if n < 3:
		errors.append("need at least 3 control points")
		return errors
	if corner_radii.size() != n:
		errors.append("corner_radii must have one radius per control point")
		return errors
	for i in n:
		if corner_radii[i] <= road_width * 0.5:
			errors.append("corner %d radius %.0f must exceed half the road width" % [i, corner_radii[i]])
		var j := (i + 1) % n
		var room := control_points[i].distance_to(control_points[j])
		if _tangent_length(i) + _tangent_length(j) > room:
			errors.append("corners %d and %d overlap (no room for a straight)" % [i, j])
	if errors.is_empty():
		errors.append_array(validate_elevation())
		errors.append_array(validate_jumps())
	return errors


func has_elevation() -> bool:
	return not elevation_zones.is_empty()


func has_jumps() -> bool:
	return not jumps.is_empty()


## The jump whose ramp-to-gap span contains arc distance s (index), or -1.
func jump_at(s: float, lap_length: float) -> int:
	var w := fposmod(s, lap_length)
	for k in jumps.size():
		var j := jumps[k]
		if w >= j.x - j.y and w < j.x + j.z:
			return k
	return -1


## Problems with the jumps (empty when valid): each on one straight with room
## to line up and to land, on the ground level, clear of bridge ends,
## crossings and the starting grid, not overlapping another.
func validate_jumps() -> PackedStringArray:
	var errors := PackedStringArray()
	if jumps.is_empty():
		return errors
	var c := sample_centerline()
	var path := ClosedPath.new(c)
	var tans := tangents(c)
	var crossings := find_crossings(c)
	for k in jumps.size():
		var j := jumps[k]
		if j.y <= 0.0 or j.z <= 0.0:
			errors.append("jump %d needs a ramp and a gap" % k)
			continue
		var from := j.x - j.y - JUMP_RUNWAY
		var to := j.x + j.z + JUMP_RUNWAY
		if from < 0.0 or to > path.length - grid_extent():
			errors.append("jump %d is too close to the start line / grid" % k)
		var dir := path.tangent_at(from)
		var s := from
		while s <= to:
			var i := path.index_at(s)
			if absf(tans[i].angle_to(dir)) > 0.02:
				errors.append("jump %d must be on one straight (with %.0f px either side)" % [k, JUMP_RUNWAY])
				break
			if level_at(s, path.length) != 0 or in_transition(s, path.length):
				errors.append("jump %d must be on the ground, clear of bridge ends" % k)
				break
			s += sample_spacing
		for x in crossings:
			for s_branch in [x.s_a, x.s_b]:
				if s_branch > from - crossing_reach(x.angle) and s_branch < to + crossing_reach(x.angle):
					errors.append("jump %d is too close to a crossing" % k)
		for m in range(k + 1, jumps.size()):
			var o := jumps[m]
			if from < o.x + o.z + JUMP_RUNWAY and o.x - o.y - JUMP_RUNWAY < to:
				errors.append("jumps %d and %d overlap" % [k, m])
	var gates := checkpoint_sample_indices(c.size(), c)
	for g in range(1, gates.size()):
		if not _gate_allowed(path.cumulative[gates[g]], c[gates[g]], path, crossings):
			errors.append("checkpoint %d could not be placed clear of the jumps" % g)
	return errors


## True within TRANSITION_BAND of either end of an elevation zone.
func in_transition(s: float, lap_length: float) -> bool:
	var w := fposmod(s, lap_length)
	for z in elevation_zones:
		for s_end in [z.x, z.y]:
			if absf(wrapf(w - s_end, -lap_length * 0.5, lap_length * 0.5)) < TRANSITION_BAND:
				return true
	return false


## Road level at arc distance s (any value; wrapped onto the lap):
## 1 inside an elevation zone, otherwise 0.
func level_at(s: float, lap_length: float) -> int:
	if elevation_zones.is_empty():
		return 0
	var w := fposmod(s, lap_length)
	for z in elevation_zones:
		if w >= z.x and w < z.y:
			return 1
	return 0


## Where the centreline crosses itself: [{point, s_a, s_b, angle}] with
## s_a < s_b the arc distances of the two branches and angle (radians, 0..PI/2)
## between them. Touching neighbouring segments do not count.
static func find_crossings(c: PackedVector2Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path := ClosedPath.new(c)
	var n := c.size()
	for i in n:
		var a0 := c[i]
		var a1 := c[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			var hit = Geometry2D.segment_intersects_segment(a0, a1, c[j], c[(j + 1) % n])
			if hit == null:
				continue
			var dup := false
			for o in out:
				if o.point.distance_to(hit) < 5.0:
					dup = true
			if dup:
				continue
			var sa: float = path.cumulative[i] + a0.distance_to(hit)
			var sb: float = path.cumulative[j] + c[j].distance_to(hit)
			var ang := absf((a1 - a0).angle_to(c[(j + 1) % n] - c[j]))
			if ang > PI * 0.5:
				ang = PI - ang
			out.append({"point": hit, "s_a": sa, "s_b": sb, "angle": ang})
	return out


## Half the stretch of a branch (px) that lies over / under the other road at
## a crossing of the given angle, plus clearance.
func crossing_reach(angle: float) -> float:
	return (road_width * 0.5 + CROSSING_CLEARANCE) / maxf(sin(angle), 0.2)


## Problems with crossings and elevation zones (empty when valid). A flat
## circuit with no crossing has none.
func validate_elevation() -> PackedStringArray:
	var errors := PackedStringArray()
	var c := sample_centerline()
	var path := ClosedPath.new(c)
	var crossings := find_crossings(c)
	if crossings.is_empty() and elevation_zones.is_empty():
		return errors
	if crossings.is_empty():
		errors.append("elevation zones but no crossing")
	if TRANSITION_BAND >= GATE_ZONE_MARGIN:
		errors.append("transition band must be narrower than the gate margin")
	for k in elevation_zones.size():
		var z := elevation_zones[k]
		if z.x < 0.0 or z.y > path.length or z.x >= z.y:
			errors.append("zone %d must lie within the lap (0..%.0f) with start < end" % [k, path.length])
		for m in range(k + 1, elevation_zones.size()):
			var o := elevation_zones[m]
			if z.x < o.y and o.x < z.y:
				errors.append("zones %d and %d overlap" % [k, m])
	var away := road_width * 0.5 + CROSSING_CLEARANCE
	for x in crossings:
		var reach := crossing_reach(x.angle)
		var up_a := level_at(x.s_a, path.length) == 1
		var up_b := level_at(x.s_b, path.length) == 1
		if up_a == up_b:
			errors.append("crossing at %s needs exactly one elevated branch" % x.point)
			continue
		var s_up: float = x.s_a if up_a else x.s_b
		if level_at(s_up - reach, path.length) != 1 or level_at(s_up + reach, path.length) != 1:
			errors.append("zone must cover %.0f px either side of the crossing at %s" % [reach, x.point])
		for s_branch in [x.s_a, x.s_b]:
			if minf(s_branch, path.length - s_branch) < away + grid_extent():
				errors.append("crossing at %s is too close to the start line / grid" % x.point)
	# Zone ends (where cars change level) must be clear of the other road.
	for z in elevation_zones:
		for s_end in [z.x, z.y]:
			var p := path.point_at(s_end)
			for i in c.size():
				var gap := absf(wrapf(path.cumulative[i] - s_end, -path.length * 0.5, path.length * 0.5))
				if gap > road_width * 3.0 and c[i].distance_to(p) < away + road_width * 0.5:
					errors.append("zone end at %.0f px is too close to another part of the road" % s_end)
					break
	# The grid and the start line stay on level 0.
	for s_grid in [0.0, path.length - grid_extent()]:
		if level_at(s_grid, path.length) != 0:
			errors.append("start line and grid must be on the ground level")
	for z in elevation_zones:
		if z.y > path.length - grid_extent():
			errors.append("a zone reaches into the starting grid")
	# Checkpoint gates: off the bridge, clear of crossings and zone ends.
	var gates := checkpoint_sample_indices(c.size(), c)
	for g in gates.size():
		var sg := path.cumulative[gates[g]]
		if not _gate_allowed(sg, c[gates[g]], path, crossings):
			errors.append("checkpoint %d could not be placed clear of the crossing" % g)
	return errors


## How far behind the start line the starting grid reaches (px).
func grid_extent() -> float:
	return grid_first_offset + 4 * grid_row_spacing + grid_stagger + 40.0


func _gate_allowed(s: float, at: Vector2, path: ClosedPath, crossings: Array[Dictionary]) -> bool:
	if level_at(s, path.length) != 0:
		return false
	for j in jumps:  # never on a jump, nor where cars line up for it or land
		if s > j.x - j.y - JUMP_RUNWAY and s < j.x + j.z + JUMP_RUNWAY:
			return false
	for z in elevation_zones:
		for s_end in [z.x, z.y]:
			if absf(wrapf(s - s_end, -path.length * 0.5, path.length * 0.5)) < GATE_ZONE_MARGIN:
				return false
	for x in crossings:
		if at.distance_to(x.point) < road_width + CROSSING_CLEARANCE:
			return false
	return true


## Closed centreline sampled at most sample_spacing apart. Index 0 is the
## start/finish line: the middle of the straight leading into control point 0.
func sample_centerline() -> PackedVector2Array:
	var n := control_points.size()
	var pts := PackedVector2Array()
	var last := n - 1
	var start := (_corner_exit(last) + _corner_entry(0)) * 0.5
	_sample_straight(pts, start, _corner_entry(0))
	for i in n:
		_sample_arc(pts, i)
		var next_entry := _corner_entry((i + 1) % n) if i < last else start
		_sample_straight(pts, _corner_exit(i), next_entry)
	return pts


func _direction_in(i: int) -> Vector2:
	var n := control_points.size()
	return (control_points[i] - control_points[(i - 1 + n) % n]).normalized()


func _direction_out(i: int) -> Vector2:
	return (control_points[(i + 1) % control_points.size()] - control_points[i]).normalized()


func _turn_angle(i: int) -> float:
	return _direction_in(i).angle_to(_direction_out(i))


func _tangent_length(i: int) -> float:
	return corner_radii[i] * tan(absf(_turn_angle(i)) * 0.5)


func _corner_entry(i: int) -> Vector2:
	return control_points[i] - _direction_in(i) * _tangent_length(i)


func _corner_exit(i: int) -> Vector2:
	return control_points[i] + _direction_out(i) * _tangent_length(i)


func _sample_straight(pts: PackedVector2Array, from: Vector2, to: Vector2) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) / sample_spacing))
	for s in steps:
		pts.append(from.lerp(to, float(s) / steps))


func _sample_arc(pts: PackedVector2Array, i: int) -> void:
	var turn := _turn_angle(i)
	if is_zero_approx(turn):
		return
	var r := corner_radii[i]
	var inward := _direction_in(i).rotated(signf(turn) * PI * 0.5)
	var centre := _corner_entry(i) + inward * r
	var a0 := (_corner_entry(i) - centre).angle()
	var steps := maxi(1, ceili(absf(turn) * r / sample_spacing))
	for s in steps:
		pts.append(centre + Vector2.from_angle(a0 + turn * float(s) / steps) * r)


## Unit tangent (driving direction) at each centreline sample.
static func tangents(centerline: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := centerline.size()
	for i in n:
		out.append((centerline[(i + 1) % n] - centerline[(i - 1 + n) % n]).normalized())
	return out


## Centreline offset sideways by distance (positive = right of driving direction).
static func offset_line(centerline: PackedVector2Array, distance: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var tans := tangents(centerline)
	for i in centerline.size():
		var right := Vector2(-tans[i].y, tans[i].x)
		out.append(centerline[i] + right * distance)
	return out


## Sample indices of the checkpoints, evenly spaced, index 0 = start/finish.
## With elevation zones or jumps (and the centreline given), a gate that would
## sit on the bridge, at a crossing, by a zone end or on a jump moves forward
## to the first clear sample (or back, when there is no room before the next).
func checkpoint_sample_indices(sample_count: int, centerline: PackedVector2Array = PackedVector2Array()) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in checkpoint_count:
		out.append(int(round(float(c) * sample_count / checkpoint_count)) % sample_count)
	if (elevation_zones.is_empty() and jumps.is_empty()) or centerline.size() != sample_count:
		return out
	var path := ClosedPath.new(centerline)
	var crossings := find_crossings(centerline)
	for g in range(1, out.size()):
		var target := out[g]
		var limit := out[g + 1] if g + 1 < out.size() else sample_count
		var i := target
		while i < limit - 1 and not _gate_allowed(path.cumulative[i], centerline[i], path, crossings):
			i += 1
		if not _gate_allowed(path.cumulative[i], centerline[i], path, crossings):
			# no room ahead before the next gate: move back instead (still after the previous one)
			i = target
			while i > out[g - 1] + 1 and not _gate_allowed(path.cumulative[i], centerline[i], path, crossings):
				i -= 1
		out[g] = i
	return out
