class_name TrackLayout
extends Resource
## Data for one closed circuit: a smooth centreline through control points.
## Sampling is pure (no scene), so geometry and checkpoints can be unit-tested.

## Control points of the closed centreline, in world pixels, in driving order.
@export var control_points: PackedVector2Array
## Drivable width between the barrier faces (px). PROVISIONAL (original: ~3 cars wide).
@export var road_width := 150.0
## Centreline samples between two control points.
@export var samples_per_segment := 12
## Number of checkpoints including the start/finish line (checkpoint 0).
@export var checkpoint_count := 8
## Laps per race. PROVISIONAL: the original's lap count per track is unverified.
@export var lap_count := 3
## Distance the car starts ahead of the start/finish line (px).
@export var start_offset := 70.0


## Closed Catmull-Rom centreline; index 0 is the start/finish line.
func sample_centerline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := control_points.size()
	for i in n:
		var p0 := control_points[(i - 1 + n) % n]
		var p1 := control_points[i]
		var p2 := control_points[(i + 1) % n]
		var p3 := control_points[(i + 2) % n]
		for s in samples_per_segment:
			var t := float(s) / samples_per_segment
			var t2 := t * t
			var t3 := t2 * t
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return pts


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
