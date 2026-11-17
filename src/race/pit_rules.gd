class_name PitRules
extends Resource
## Pit lanes (2026-11-17): service, the pit limiter and speeding penalties.
## Provisional numbers for human balancing (docs/PIT_LANES.md).

## Service: condition points restored (never above 100 %), seconds stationary
## in the service box, and the speed (px/s) below which a car counts as stopped.
@export var repair_points := 30.0
@export var service_time := 6.0
@export var stopped_speed := 12.0
## The pit limiter: share of the car's top speed allowed in the pit lane.
@export_range(0.1, 1.0) var limiter_share := 0.5
## Override: two separate accelerator presses within this many seconds.
@export var double_tap_window := 0.35
## Speeding ticket: a fine in garage races (money, deducted from the winnings
## or the garage balance, never below $0) ...
@export var fine := 150
## ... or, where there is no money (other modes and every rival), a sporting
## penalty: the car is held to the limiter speed this many seconds after it
## leaves the pit lane.
@export var penalty_time := 3.0
