extends GutTest
## M5.1 Stage 1: two separate Godot processes (host and client) race over
## localhost through the real ENet transport; both humans are autopilots that
## steer through the normal input paths (the client's car only through INPUT
## messages). Both processes must show the same authoritative result, also
## with simulated latency and packet loss, and keep the reversed grid with the
## rival rotation across consecutive races.

const OUT := "user://net_probe_%s.json"


## Waits in real time (the suite runs with --fixed-fps, where GUT's waits are
## simulated time; the two child processes run in real time).
func _real_wait(ms: int, done: Callable) -> void:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline and not done.call():
		OS.delay_msec(20)
		await wait_frames(1)


func _run(port: int, args: Array) -> Array:
	var h := ProjectSettings.globalize_path(OUT % ("host_%d" % port))
	var c := ProjectSettings.globalize_path(OUT % ("client_%d" % port))
	for f in [h, c]:
		DirAccess.remove_absolute(f)
	var base := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "res://tests/support/net_probe.gd", "--"]
	var common := ["port=%d" % port] + args
	var hp := OS.create_process(OS.get_executable_path(), PackedStringArray(base + ["role=host", "out=" + h] + common))
	await _real_wait(500, func() -> bool: return false)
	var cp := OS.create_process(OS.get_executable_path(), PackedStringArray(base + ["role=client", "out=" + c] + common))
	await _real_wait(150000, func() -> bool: return FileAccess.file_exists(h) and FileAccess.file_exists(c))
	await _real_wait(500, func() -> bool: return false)
	for pid in [hp, cp]:
		if OS.is_process_running(pid):
			OS.kill(pid)
	var out := []
	for f in [h, c]:
		out.append(JSON.parse_string(FileAccess.get_file_as_string(f)) if FileAccess.file_exists(f) else {})
		DirAccess.remove_absolute(f)
	return out


func test_host_and_client_agree_on_the_result() -> void:
	var r := await _run(24711, ["laps=1"])
	assert_true(r[0].has("results"), str(r[0]))
	assert_true(r[1].has("results"), str(r[1]))
	if not r[0].has("results") or not r[1].has("results"):
		return
	var host: Dictionary = r[0].results[0]
	assert_eq(r[1].results[0], host, "client shows the host's authoritative result")
	assert_eq(host.order.size(), 10, "two humans and eight rivals")
	assert_has(host.order, float(RaceSession.PLAYER_2_ID), "the client's car finished, driven only by network input")
	assert_eq(host.sitting_out, [1.0], "Victor sits out the first race")


func test_two_races_with_latency_and_loss_keep_agreeing_and_rotate() -> void:
	var r := await _run(24712, ["laps=1", "races=2", "latency=60", "loss=0.1"])
	if not r[0].has("results") or not r[1].has("results"):
		fail_test("no results: %s / %s" % [str(r[0]), str(r[1])])
		return
	assert_eq(r[1].results, r[0].results, "both races agree")
	var first: Dictionary = r[0].results[0]
	var second: Dictionary = r[0].results[1]
	var expected: Array = first.order.duplicate()
	expected.reverse()
	expected[expected.find(2.0)] = 1.0
	assert_eq(second.grid, expected, "reversed grid; returning Victor takes Rocco's slot")
	assert_eq(second.sitting_out, [2.0])


func test_armed_races_agree_classic_and_tactical() -> void:
	for style in [0, 1]:
		var r := await _run(24713 + style, ["laps=1", "weapons=1", "style=%d" % style, "fire_every=45", "latency=30", "loss=0.05"])
		if not r[0].has("results") or not r[1].has("results"):
			fail_test("style %d no results: %s / %s" % [style, str(r[0]), str(r[1])])
			continue
		var host: Dictionary = r[0].results[0]
		assert_eq(r[1].results[0], host, "style %d: same result, shots and destructions on both" % style)
		assert_gt(host.fired, 0.0)
		assert_gt(r[0].client_shots, 0.0, "the client's player fired through the network")
