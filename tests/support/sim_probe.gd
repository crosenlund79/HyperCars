extends SceneTree
## Test helper, run in a fresh Godot process by the determinism tests:
##   godot --headless --path <project> --fixed-fps 60 -s res://tests/support/sim_probe.gd -- \
##         mode=race|spectate speed=1 presentation=1 ticks=900
## Prints "PROBE <md5>" of every car's and driver's exact state after `ticks`.
## A fresh process matters: Godot's physics broadphase keeps history between
## scenes in one process, which changes the order multi-car contacts resolve.

var main: Node2D
var opts := {"mode": "spectate", "speed": "1", "presentation": "1", "ticks": "900", "weapons": "0"}
var tick := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2:
			opts[kv[0]] = kv[1]
	main = load("res://src/main/main.tscn").instantiate()
	main.presentation_enabled = opts.presentation == "1"
	root.add_child(main)
	physics_frame.connect(_on_tick)


func _on_tick() -> void:
	tick += 1
	if tick == 2:
		if main.has_method("set_weapons_enabled"):
			main.set_weapons_enabled(opts.weapons == "1")
		if opts.mode == "spectate":
			main.set_menu_choice(2)
		main.set_sim_speed(int(opts.speed))
		main.start_race()
		if opts.mode == "race":
			Input.action_press("fire")
	if opts.mode == "race" and tick > 2:
		# Scripted player steering, identical in every run.
		if tick % 90 == 30:
			Input.action_press("steer_right")
		elif tick % 90 == 45:
			Input.action_release("steer_right")
	if tick == 2 + int(opts.ticks):
		var s := []
		for c in main.cars:
			s.append_array([c.global_position, c.model.velocity, c.model.heading])
		for d in main.drivers:
			if d != null:
				s.append_array([d.lane_bias, d.commitment, d.fluster_time])
		for r in main.session.racers:
			s.append_array([r.progress, r.tracker.laps_completed, r.tracker.next_checkpoint])
		if main.get("combat") != null:
			s.append(main.combat.state_snapshot())
		print("PROBE ", var_to_bytes(s).hex_encode().md5_text())
		main.set_sim_speed(1)
		quit()
