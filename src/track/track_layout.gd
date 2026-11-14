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
## Distance the car starts ahead of the start/finish line (px).
@export var start_offset := 70.0


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
	return errors


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
func checkpoint_sample_indices(sample_count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in checkpoint_count:
		out.append(int(round(float(c) * sample_count / checkpoint_count)) % sample_count)
	return out
