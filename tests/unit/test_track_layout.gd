extends GutTest
## TrackLayout geometry: closed centreline, edges, checkpoints; circuit_01 sanity.

const CIRCUIT := "res://src/track/circuit_01.tres"


func _square() -> TrackLayout:
	var l := TrackLayout.new()
	l.control_points = PackedVector2Array([Vector2(0, 0), Vector2(1000, 0), Vector2(1000, 1000), Vector2(0, 1000)])
	l.samples_per_segment = 10
	l.checkpoint_count = 4
	return l


func test_centerline_passes_through_control_points() -> void:
	var l := _square()
	var c := l.sample_centerline()
	assert_eq(c.size(), 40)
	assert_eq(c[0], Vector2(0, 0), "sample 0 is the start/finish line")
	assert_eq(c[10], Vector2(1000, 0))


func test_offset_line_is_perpendicular_at_given_distance() -> void:
	var c := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)])
	var right := TrackLayout.offset_line(c, 50.0)
	assert_almost_eq(right[1], Vector2(100, 50), Vector2(0.001, 0.001), "+distance is right of travel (screen +Y)")


func test_checkpoints_evenly_spaced_starting_at_zero() -> void:
	var l := _square()
	assert_eq(l.checkpoint_sample_indices(40), PackedInt32Array([0, 10, 20, 30]))


func test_circuit_edges_do_not_self_intersect() -> void:
	var l: TrackLayout = load(CIRCUIT)
	var c := l.sample_centerline()
	for edge in [TrackLayout.offset_line(c, -l.road_width * 0.5), TrackLayout.offset_line(c, l.road_width * 0.5)]:
		var n: int = edge.size()
		var crossings := 0
		for i in n:
			for j in range(i + 2, n):
				if i == 0 and j == n - 1:
					continue
				if Geometry2D.segment_intersects_segment(edge[i], edge[(i + 1) % n], edge[j], edge[(j + 1) % n]) != null:
					crossings += 1
		assert_eq(crossings, 0)


func test_circuit_has_valid_race_settings() -> void:
	var l: TrackLayout = load(CIRCUIT)
	assert_gte(l.checkpoint_count, 2)
	assert_gte(l.lap_count, 1)
	assert_gt(l.road_width, 0.0)
