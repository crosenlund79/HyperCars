class_name CarModel
extends RefCounted
## Pure, deterministic top-down driving model (no scene dependencies).
## Heading 0 points along +X. Steering rotates the car; velocity keeps its
## momentum and is pulled towards the heading by grip, which produces sliding.

enum ControlMode { FIRE_TO_ACCELERATE, FIRE_TO_BRAKE }

var params: DrivingParams
var control_mode: ControlMode = ControlMode.FIRE_TO_ACCELERATE
var position := Vector2.ZERO
var heading := 0.0
var velocity := Vector2.ZERO


func _init(p_params: DrivingParams = null, p_mode: ControlMode = ControlMode.FIRE_TO_ACCELERATE) -> void:
	params = p_params if p_params != null else DrivingParams.new()
	control_mode = p_mode


func forward() -> Vector2:
	return Vector2.from_angle(heading)


func forward_speed() -> float:
	return velocity.dot(forward())


func lateral_speed() -> float:
	return velocity.dot(forward().orthogonal())


## True when the current input means "accelerate" in the active control mode.
func is_accelerating(fire: bool) -> bool:
	return fire if control_mode == ControlMode.FIRE_TO_ACCELERATE else not fire


## Deceleration applied when not accelerating, per control mode.
func braking_deceleration() -> float:
	return params.release_deceleration if control_mode == ControlMode.FIRE_TO_ACCELERATE else params.brake_deceleration


## Advances velocity and heading by delta. steer: -1 left, 0 none, +1 right.
func update(delta: float, steer: float, fire: bool) -> void:
	var steer_factor := 1.0
	if params.full_steer_speed > 0.0:
		steer_factor = clampf(velocity.length() / params.full_steer_speed, 0.0, 1.0)
	heading = wrapf(heading + clampf(steer, -1.0, 1.0) * deg_to_rad(params.turn_rate_degrees) * steer_factor * delta, -PI, PI)

	var fwd_dir := forward()
	var side_dir := fwd_dir.orthogonal()
	var fwd := velocity.dot(fwd_dir)
	var side := velocity.dot(side_dir)

	if is_accelerating(fire):
		if fwd < params.max_speed:
			fwd = minf(fwd + params.acceleration * delta, params.max_speed)
		else:
			fwd = move_toward(fwd, params.max_speed, braking_deceleration() * delta)
	else:
		fwd = move_toward(fwd, 0.0, braking_deceleration() * delta)

	side *= exp(-params.grip * delta)
	velocity = fwd_dir * fwd + side_dir * side


## Moves position by velocity (used when no physics body integrates the motion).
func integrate(delta: float) -> void:
	position += velocity * delta


## Collision response against a wall with outward normal (pointing towards the car).
func apply_wall_collision(normal: Vector2) -> void:
	var into := velocity.dot(normal)
	if into >= 0.0:
		return
	var tangent := velocity - normal * into
	velocity = tangent * params.wall_tangent_retention - normal * into * params.wall_restitution


## Equal-mass contact between two cars. normal points from b towards a.
## Only the closing velocity along the normal changes, identically for both cars.
static func resolve_car_collision(a: CarModel, b: CarModel, normal: Vector2) -> void:
	var closing := (a.velocity - b.velocity).dot(normal)
	if closing >= 0.0:
		return
	var restitution := (a.params.car_restitution + b.params.car_restitution) * 0.5
	var impulse := -(1.0 + restitution) * closing * 0.5
	a.velocity += normal * impulse
	b.velocity -= normal * impulse
