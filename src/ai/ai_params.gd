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

## --- Personality (decision traits). Defaults are neutral and reproduce the M2 driver.
## How far ahead (seconds at current speed) the driver reads the target speed;
## smaller = brakes later.
@export var brake_anticipation := 0.1
## Target-speed scale inside braking/corner zones (>1 = pushes harder than the plan).
@export var corner_commitment := 1.0
## Random +- variation of corner_commitment, rolled per corner (consistency).
@export var commitment_variation := 0.0
## Chance per corner of over-committing, and the extra commitment when it happens.
@export var overcommit_chance := 0.0
@export var overcommit_extra := 0.0
## Extra commitment when chasing a car within traffic_distance.
@export var chase_aggression := 0.0
## Only start a pass when the line ahead is a straight (no braking zone within pass_lookahead).
@export var pass_on_straights_only := false
@export var pass_lookahead := 300.0
## Pressure: a car within pressure_distance behind or alongside. 0 disables.
@export var pressure_distance := 0.0
## Chance per second under pressure of becoming flustered, and how long it lasts (s).
@export var fluster_chance_per_second := 0.0
@export var fluster_duration := 1.0
## While flustered: chance per tick of lifting off (hesitation) ...
@export var fluster_lift_chance := 0.0
## ... and over-correction: look-ahead shrinks by this fraction and the steering deadband vanishes.
@export var fluster_overcorrection := 0.0

## --- M2.3 traits (neutral defaults: no effect).
## Defending: when a closing car is within defend_distance behind, move towards
## its line by defend_strength (0..1) and scale corner commitment by
## defend_commitment (gives up speed to keep the position). 0 disables.
@export var defend_distance := 0.0
@export var defend_strength := 0.0
@export var defend_commitment := 1.0
## Only pass into a lane with no other car nearby (no forcing).
@export var pass_check_clearance := false
## Passing side: 0 = nearest side, 1 = outside of the coming corner, 2 = random per attempt.
@export_range(0, 2) var pass_side := 0
## Disrupted line: when pushed more than disrupted_threshold px off the planned
## line, corner commitment is scaled by disrupted_commitment for disrupted_recovery s. 0 disables.
@export var disrupted_threshold := 0.0
@export var disrupted_commitment := 1.0
@export var disrupted_recovery := 0.0
## Chance per second of attempting a pass even without a speed advantage (impulse).
@export var pass_impulse_chance := 0.0
