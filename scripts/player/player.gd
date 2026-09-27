extends CharacterBody2D

@export var player_id: int = 1 

var left_action: String
var right_action: String
var jump_action: String
var attack_action: String

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

var is_attacking: bool = false
var current_attack_damage: float = 10.0
var combo_step: int = 0
var combo_buffered: bool = false
var can_combo: bool = false

func _ready() -> void:
	left_action = "p1_left" if player_id == 1 else "p2_left"
	right_action = "p1_right" if player_id == 1 else "p2_right"
	jump_action = "p1_jump" if player_id == 1 else "p2_jump"
	attack_action = "p1_attack" if player_id == 1 else "p2_attack"

	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if _lunging:
		if not is_on_floor():
			_lunging = false
			_lunge_time = 0.0
		elif not Input.is_action_pressed(jump_action):
			_lunging = false
			velocity.y = _charged_jump_velocity()
			_lunge_time = 0.0
		else:
			_lunge_time = minf(_lunge_time + delta, MAX_LUNGE_TIME)
	elif Input.is_action_pressed(jump_action) and is_on_floor():
		_lunging = true
		_lunge_time = 0.0

	if not is_on_floor() and not _lunging:
		velocity += get_gravity() * delta

	var direction := 0.0 if _lunging else Input.get_axis(left_action, right_action)
	if _lunging:
		velocity.x = 0.0
	elif direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if Input.is_action_just_pressed(attack_action):
		if not is_attacking:
			punch_1()
		elif can_combo:
			combo_buffered = true
		
	move_and_slide()
	_update_animation(direction)

func _update_animation(direction: float) -> void:
	if is_attacking:
		if combo_step == 1 and _sprite.animation != &"surgeon_unarmed_single_light":
			_sprite.play(&"surgeon_unarmed_single_light")
		elif combo_step == 2 and _sprite.animation != &"surgeon_unarmed_combo":
			_sprite.play(&"surgeon_unarmed_combo")
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

func punch_1() -> void:
	is_attacking = true
	combo_step = 1
	combo_buffered = false
	can_combo = false
	current_attack_damage = 10.0
	anim_player.play("Punch")

func punch_2() -> void:
	combo_step = 2
	combo_buffered = false
	can_combo = false
	current_attack_damage = 15.0
	anim_player.play("Punch2")

func enable_combo_window() -> void:
	can_combo = true

func check_combo() -> void:
	if combo_buffered:
		punch_2()
	else:
		finish_attack()

func finish_attack() -> void:
	is_attacking = false
	combo_step = 0
	combo_buffered = false
	can_combo = false

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

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body != self and body.has_method("take_damage"):
		body.take_damage(current_attack_damage)
