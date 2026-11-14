class_name DrivingParams
extends Resource
## Tunable driving parameters for fidelity calibration.
##
## ALL VALUES ARE PROVISIONAL - chosen for playability, NOT verified against
## the 1991 Amiga Super Cars II. Units: world pixels and seconds.
## Behaviour (from the manual, as confirmed by the user):
##   Fire to Accelerate: fire held = accelerate; fire released = brake automatically.
##   Fire to Brake: accelerates automatically; fire held = stronger braking.

## Top forward speed (px/s). PROVISIONAL.
@export var max_speed: float = 420.0
## Forward acceleration while accelerating (px/s^2). PROVISIONAL.
@export var acceleration: float = 260.0
## Fire to Accelerate mode: deceleration while fire is released (px/s^2). PROVISIONAL.
@export var release_deceleration: float = 200.0
## Fire to Brake mode: deceleration while fire is held; must exceed release_deceleration (px/s^2). PROVISIONAL.
@export var brake_deceleration: float = 520.0
## Rotation speed while steering (degrees/s). PROVISIONAL; original rotation steps unknown.
@export var turn_rate_degrees: float = 210.0
## Speed below which turning is scaled down linearly; 0 = full turning at any speed. PROVISIONAL.
@export var full_steer_speed: float = 0.0
## How fast sideways (sliding) velocity decays, per second. Lower = more slide. PROVISIONAL.
@export var grip: float = 4.5
## Fraction of the into-wall speed bounced back on impact (0..1). PROVISIONAL.
@export_range(0.0, 1.0) var wall_restitution: float = 0.3
## Fraction of the along-wall speed kept on impact (0..1). PROVISIONAL.
@export_range(0.0, 1.0) var wall_tangent_retention: float = 0.75
