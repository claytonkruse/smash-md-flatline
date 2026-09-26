extends CharacterBody2D


const SPEED = 500.0
const JUMP_VELOCITY = -1000.0
const MAX_JUMP_HEIGHT_SCALE = 6.0
const MAX_LUNGE_TIME = 1.0
const FLOAT_VELOCITY = 90.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _lunging := false
var _lunge_time := 0.0


func _physics_process(delta: float) -> void:
	if _lunging:
		if not is_on_floor():
			_lunging = false
			_lunge_time = 0.0
		elif not Input.is_action_pressed("ui_accept"):
			_lunging = false
			velocity.y = _charged_jump_velocity()
			_lunge_time = 0.0
		else:
			_lunge_time = minf(_lunge_time + delta, MAX_LUNGE_TIME)
	elif Input.is_action_pressed("ui_accept") and is_on_floor():
		_lunging = true
		_lunge_time = 0.0

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


func _charged_jump_velocity() -> float:
	var charge := _lunge_time / MAX_LUNGE_TIME
	var height_scale := lerpf(1.0, MAX_JUMP_HEIGHT_SCALE, charge)
	return JUMP_VELOCITY * sqrt(height_scale)


func _airborne_animation() -> StringName:
	if velocity.y < -FLOAT_VELOCITY:
		return &"surgeon_unarmed_jump"
	if velocity.y > FLOAT_VELOCITY:
		return &"surgeon_unarmed_land"
	return &"surgeon_unarmed_float"
