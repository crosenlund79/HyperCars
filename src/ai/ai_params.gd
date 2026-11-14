class_name AiParams
extends Resource
## Tunables for computer drivers. These shape decisions only: AI cars use the
## same DrivingParams, CarModel and inputs (digital left/right + fire) as the
## player, with no speed, grip or catch-up advantages.
## All values PROVISIONAL: the original AI behaviour is undocumented.

## Distance kept between the racing line and the barrier faces (px).
@export var line_margin := 34.0
## Smoothing passes used to straighten the racing line through corners.
@export var line_iterations := 300
## Fraction of the steering-limited speed (turn rate x radius) used as corner speed.
@export var corner_speed_factor := 0.85
## Fraction of release_deceleration assumed when planning braking.
@export var brake_planning_factor := 0.8
## Steering look-ahead: base distance (px) plus distance per px/s of speed.
@export var lookahead_base := 60.0
@export var lookahead_per_speed := 0.22
## Heading error below which the driver does not steer (degrees).
@export var steer_deadband_degrees := 4.0
## Cars closer than this ahead (px along the track) are treated as traffic.
@export var traffic_distance := 150.0
## Pass only cars at least this much slower (px/s); otherwise follow.
@export var pass_speed_margin := 4.0
## Gap (px) below which a driver eases off rather than run into the car ahead.
@export var follow_gap := 85.0
## Lateral gap (px) below which a car ahead is in our path.
@export var car_clearance := 42.0
## Lateral position (px from the other car) used when moving out to pass.
@export var pass_offset := 50.0
## Minimum distance between a passing car's centre and the barrier face (px).
@export var pass_margin := 24.0
## Rate the driver moves sideways when changing line (px/s), and returns to the racing line.
@export var lane_change_rate := 110.0
@export var lane_return_rate := 45.0
