class_name RacingLine
extends RefCounted
## Racing line for one track: lateral offsets from the centreline that cut
## corners within the road, and a target speed at every sample derived from the
## shared driving parameters (steering-limited corner speed + braking distance).
## Pure data, built once per track; samples match the centreline samples.

var center: ClosedPath
var offsets := PackedFloat32Array()
var speeds := PackedFloat32Array()
## Furthest the racing line itself goes from the centreline (px).
var max_lateral := 0.0
var road_half_width := 0.0
## Per sample (narrow sections): half the road width and the line's limit;
## empty = road_half_width / max_lateral everywhere.
var half_widths := PackedFloat32Array()
var _max_lat := PackedFloat32Array()
## Highest target speed on the line (straights).
var top_speed := 0.0
var _normals := PackedVector2Array()


func _init(p_center: ClosedPath, road_width: float, driving: DrivingParams, ai: AiParams,
		p_half_widths: PackedFloat32Array = PackedFloat32Array()) -> void:
	center = p_center
	road_half_width = road_width * 0.5
	max_lateral = maxf(0.0, road_half_width - ai.line_margin)
	if p_half_widths.size() == center.points.size():
		half_widths = p_half_widths
		for h in half_widths:
			_max_lat.append(maxf(0.0, h - ai.line_margin))
	var n := center.points.size()
	for i in n:
		var t := (center.points[(i + 1) % n] - center.points[(i - 1 + n) % n]).normalized()
		_normals.append(Vector2(-t.y, t.x))
	offsets.resize(n)
	offsets.fill(0.0)
	_optimise(ai.line_iterations)
	_build_speeds(driving, ai)


func position(i: int) -> Vector2:
	return center.points[i] + _normals[i] * offsets[i]


## Lateral offset of the line at distance s along the centreline.
func offset_at(s: float) -> float:
	var i := center.index_at(s)
	var j := (i + 1) % center.points.size()
	var seg := center.points[i].distance_to(center.points[j])
	var t := 0.0 if seg <= 0.0 else (center.wrap_distance(s) - center.cumulative[i]) / seg
	return lerpf(offsets[i], offsets[j], clampf(t, 0.0, 1.0))


## Half the road width at distance s (narrow sections; else road_half_width).
func half_width_at(s: float) -> float:
	if half_widths.is_empty():
		return road_half_width
	return half_widths[center.index_at(s)]


func speed_at(s: float) -> float:
	return speeds[center.index_at(s)]


## World point at distance s with a given lateral offset from the centreline.
func point_with_lateral(s: float, lateral: float) -> Vector2:
	var t := center.tangent_at(s)
	return center.point_at(s) + Vector2(-t.y, t.x) * lateral


## Repeatedly pulls each point towards the midpoint of its neighbours (shortening
## and straightening the line), clamped inside the road.
func _optimise(iterations: int) -> void:
	var n := offsets.size()
	for it in iterations:
		for i in n:
			var mid := (position((i - 2 + n) % n) + position((i + 2) % n)) * 0.5
			var lim := max_lateral if _max_lat.is_empty() else _max_lat[i]
			offsets[i] = clampf((mid - center.points[i]).dot(_normals[i]), -lim, lim)


func _build_speeds(driving: DrivingParams, ai: AiParams) -> void:
	var n := offsets.size()
	speeds.resize(n)
	var turn_rate := deg_to_rad(driving.turn_rate_degrees)
	for i in n:
		var r := _radius(i)
		speeds[i] = minf(driving.max_speed, ai.corner_speed_factor * turn_rate * r)
	var decel := driving.release_deceleration * ai.brake_planning_factor
	for pass_index in 2:
		for k in n:
			var i := n - 1 - k
			var j := (i + 1) % n
			var ds := position(i).distance_to(position(j))
			speeds[i] = minf(speeds[i], sqrt(speeds[j] * speeds[j] + 2.0 * decel * ds))
	for v in speeds:
		top_speed = maxf(top_speed, v)


## Radius of the circle through the line points 3 samples either side (INF on straights).
func _radius(i: int) -> float:
	var n := offsets.size()
	var a := position((i - 3 + n) % n)
	var b := position(i)
	var c := position((i + 3) % n)
	var cross := absf((b - a).cross(c - a))
	if cross < 0.001:
		return INF
	return a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * cross)
