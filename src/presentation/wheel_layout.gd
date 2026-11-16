class_name WheelLayout
extends Resource
## Where the four shared wheels sit on a car and how they move (P2).
## Positions are display pixels relative to the car centre, car facing +X
## (the 64x36 car display size), so they do not depend on the resolution of
## a body image. Defaults fit the template bodies (default_wheel_layout.tres).

## Wheel centres: front / rear axle along the car (+ = forward), and the
## distance of each wheel from the centre line.
@export var front_x := 16.5
@export var rear_x := -16.5
@export var half_track := 12.0
## Per-car positions for differently shaped bodies:
## body logical name ("cars/body_ai_3") -> Vector3(front_x, rear_x, half_track).
@export var per_car: Dictionary = {}

@export_group("Motion (visual only)")
## Front wheels: angle at full steering, and smoothing time (s).
@export var max_steer_degrees := 26.0
@export var steer_smoothing := 0.08
## Rear wheels: sideways shift at the hardest cornering (display px), and
## smoothing time (s).
@export var rear_shift_px := 1.5
@export var rear_smoothing := 0.15


## Vector3(front_x, rear_x, half_track) for a body.
func positions(body_logical: String) -> Vector3:
	if per_car.has(body_logical):
		return per_car[body_logical]
	return Vector3(front_x, rear_x, half_track)
