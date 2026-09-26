extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const FLOAT_VELOCITY = 90.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _lunging := false


func _physics_process(delta: float) -> void:
	if _lunging:
		if not is_on_floor():
			_lunging = false
		elif not Input.is_action_pressed("ui_accept"):
			_lunging = false
			velocity.y = JUMP_VELOCITY
	elif Input.is_action_pressed("ui_accept") and is_on_floor():
		_lunging = true

	if not is_on_floor() and not _lunging:
		velocity += get_gravity() * delta

	var direction := 0.0 if _lunging else Input.get_axis("ui_left", "ui_right")
	if _lunging:
		velocity.x = 0.0
	elif direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation(direction)


func _update_animation(direction: float) -> void:
	if direction != 0.0:
		_sprite.flip_h = direction < 0.0

	var anim := _airborne_animation()
	if _lunging:
		anim = &"surgeon_unarmed_lunge"
	elif is_on_floor():
		anim = &"surgeon_unarmed_run" if direction != 0.0 else &"surgeon_unarmed_idle"

	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _airborne_animation() -> StringName:
	if velocity.y < -FLOAT_VELOCITY:
		return &"surgeon_unarmed_jump"
	if velocity.y > FLOAT_VELOCITY:
		return &"surgeon_unarmed_land"
	return &"surgeon_unarmed_float"
