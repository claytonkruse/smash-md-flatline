extends CharacterBody2D

#references
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

const SPEED = 500.0
const JUMP_VELOCITY = -1000.0
const MAX_JUMP_HEIGHT_SCALE = 6.0
const MAX_LUNGE_TIME = 1.0
const FLOAT_VELOCITY = 90.0


var _lunging := false
var _lunge_time := 0.0

#attack variables
var is_attacking: bool = false
var current_attack_damage: float = 10.0 #placeholder

#connects hitbox to damage function
func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_body_entered)

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

	# Trigger punch input
	if Input.is_action_just_pressed("attack") and not is_attacking:
		punch()
		
	move_and_slide()
	_update_animation(direction)

func _update_animation(direction: float) -> void:
	if is_attacking:
		if _sprite.animation != &"surgeon_unarmed_single_light":
			_sprite.play(&"surgeon_unarmed_single_light")
		return
		
		
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
	
func punch() -> void:
	is_attacking = true
	current_attack_damage = 10.0 #placeholder amount
	anim_player.play("Punch")
	

func finish_attack() -> void:
	print("punched")
	is_attacking = false

#calls damage method on corresponding player
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body != self and body.has_method("take_damage"):
		body.take_damage(current_attack_damage)
