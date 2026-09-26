extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = direction < 0.0

	if not is_on_floor():
		if _sprite.animation != &"surgeon_unarmed_jump":
			_sprite.play(&"surgeon_unarmed_jump")
		return

	var anim := &"surgeon_unarmed_idle"
	if direction != 0.0:
		anim = &"surgeon_unarmed_run"

	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
