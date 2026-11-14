extends GutTest
## Lighting pilot (experiment): toggles with L, stays presentation-only (a race
## is bit-identical with lighting on or off), adds no collision, and leaves the
## HUD layer undimmed.

const MAIN_SCENE := preload("res://src/main/main.tscn")


func after_each() -> void:
	Input.action_release(PlayerControls.TOGGLE_LIGHTING)


func test_lighting_does_not_change_the_race() -> void:
	var off := ProbeRunner.run(["mode=race", "ticks=900", "weapons=1", "lighting=0"])
	var on := ProbeRunner.run(["mode=race", "ticks=900", "weapons=1", "lighting=1"])
	assert_eq(off.length(), 32, off)
	assert_eq(on, off, "normal race with weapons")
	var s_off := ProbeRunner.run(["mode=spectate", "ticks=900", "weapons=0", "lighting=0"])
	var s_on := ProbeRunner.run(["mode=spectate", "ticks=900", "weapons=0", "lighting=1"])
	assert_eq(s_on, s_off, "spectating, no guns")


func test_toggle_with_l_and_light_setup() -> void:
	var m := MAIN_SCENE.instantiate()
	add_child_autofree(m)
	await wait_frames(2)
	var l: LightingPilot = m.lighting
	assert_false(l.enabled, "off by default")
	Input.action_press(PlayerControls.TOGGLE_LIGHTING)
	await wait_frames(2)
	Input.action_release(PlayerControls.TOGGLE_LIGHTING)
	assert_true(l.enabled)
	assert_eq(l._lamps.size(), LightingPilot.LAMP_COUNT, "ten trackside lamps")
	assert_eq(l._car_lights.size(), 10, "one light per car")
	assert_lte(l.light_count(), 24, "limited light count")
	assert_eq(l.find_children("*", "CollisionObject2D", true, false).size(), 0)
	assert_eq(l.find_children("*", "CanvasModulate", true, false).size(), 1)
	assert_true(m.hud is CanvasLayer, "HUD on its own layer, unaffected by the world tint")


func test_lamps_stand_clear_of_the_road() -> void:
	var m := MAIN_SCENE.instantiate()
	add_child_autofree(m)
	await wait_frames(2)
	var half: float = m.track.layout.road_width * 0.5
	for s in m.lighting._lamp_sprites:
		var p: Dictionary = m.track.path.project(s.global_position)
		assert_gt(absf(p.lateral), half, "lamp post off the road")
