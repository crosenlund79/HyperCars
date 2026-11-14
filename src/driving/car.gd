class_name Car
extends CharacterBody2D
## Scene wrapper for CarModel: applies input each physics tick, moves the body
## with continuous collision, and feeds wall contacts back into the model.
## Input is set from outside (steer/fire) so the car can be driven by tests.

signal wall_hit(normal: Vector2, impact_speed: float)

const MAX_SLIDES := 4

var model: CarModel
var steer := 0.0
var fire := false
var active := false

@onready var sprite: Sprite2D = $Sprite


func setup(params: DrivingParams, mode: CarModel.ControlMode, texture: Texture2D) -> void:
	model = CarModel.new(params, mode)
	model.position = global_position
	model.heading = global_rotation
	if texture != null:
		sprite.texture = texture
		sprite.scale = AssetCatalog.scale_for(texture, AssetCatalog.SPECS[AssetCatalog.CAR_PLAYER].display_size)


## Places the car at rest at the given transform.
func place(at: Transform2D) -> void:
	global_position = at.origin
	global_rotation = at.get_rotation()
	steer = 0.0
	fire = false
	if model != null:
		model.position = global_position
		model.heading = global_rotation
		model.velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if model == null or not active:
		return
	model.update(delta, steer, fire)
	global_rotation = model.heading
	var motion := model.velocity * delta
	for i in MAX_SLIDES:
		var collision := move_and_collide(motion)
		if collision == null:
			break
		var normal := collision.get_normal()
		var impact := -model.velocity.dot(normal)
		model.apply_wall_collision(normal)
		if impact > 0.0:
			wall_hit.emit(normal, impact)
		motion = collision.get_remainder().slide(normal) * model.params.wall_tangent_retention
		if motion.length_squared() < 0.0001:
			break
	model.position = global_position
