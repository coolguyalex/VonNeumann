extends CharacterBody2D

@export var speed: float = 400.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1200.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jump_velocity

	velocity.x = Input.get_axis("move_left", "move_right") * speed

	move_and_slide()
