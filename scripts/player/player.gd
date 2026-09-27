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
const BASE_KNOCKBACK_X = 300.0
const BASE_KNOCKBACK_Y = 200.0
const KNOCKBACK_MULTIPLIER_PER_HIT = 0.35
const HIT_FLASH_TIME = 0.12
const PLAYER_2_COLOR = Color(1.0, 0.55, 0.12, 1.0)
const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	COLOR = mix(col, vec4(1.0, 1.0, 1.0, col.a), flash);
}
"""
const BLAST_LEFT = -300.0
const BLAST_RIGHT = 1450.0
const BLAST_TOP = -400.0
const BLAST_BOTTOM = 900.0
const RESPAWN_POSITION = Vector2(576, 335)

var _lunging := false
var _lunge_time := 0.0
var _facing := 1.0
var _in_knockback := false
var _hitstun := 0.0
var _hit_ids: Array[int] = []
var _base_modulate := Color.WHITE
var _flash_tween: Tween

var is_attacking: bool = false
var current_attack_damage: float = 10.0
var knockback_multiplier: float = 1.0
var combo_step: int = 0
var combo_buffered: bool = false
var can_combo: bool = false

@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D

func _ready() -> void:
	left_action = "p1_left" if player_id == 1 else "p2_left"
	right_action = "p1_right" if player_id == 1 else "p2_right"
	jump_action = "p1_jump" if player_id == 1 else "p2_jump"
	attack_action = "p1_attack" if player_id == 1 else "p2_attack"

	if player_id != 1:
		modulate = PLAYER_2_COLOR
	_base_modulate = modulate
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	var flash_material := ShaderMaterial.new()
	flash_material.shader = shader
	_sprite.material = flash_material
	if player_id != 1:
		_facing = -1.0
		_sprite.flip_h = true
	hitbox.scale = Vector2(_facing, 1.0)
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1
	hitbox.monitoring = true
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	if _hitstun > 0.0:
		_hitstun = maxf(_hitstun - delta, 0.0)
	if _in_knockback and is_on_floor() and _hitstun <= 0.0 and velocity.y >= 0.0:
		_in_knockback = false

	hitbox.scale = Vector2(_facing, 1.0)
	var direction := 0.0
	if _in_knockback:
		if not is_on_floor():
			velocity += get_gravity() * delta
	else:
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

		direction = 0.0 if _lunging else Input.get_axis(left_action, right_action)
		if direction != 0.0 and not is_attacking:
			_facing = signf(direction)
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
	_apply_attack_hits()
	_update_animation(direction)
	if _is_off_stage():
		_respawn()

func _update_animation(direction: float) -> void:
	_sprite.flip_h = _facing < 0.0
	if is_attacking:
		if combo_step == 1 and _sprite.animation != &"surgeon_unarmed_single_light":
			_sprite.play(&"surgeon_unarmed_single_light")
		elif combo_step == 2 and _sprite.animation != &"surgeon_unarmed_combo":
			_sprite.play(&"surgeon_unarmed_combo")
		return

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

func _apply_attack_hits() -> void:
	if hitbox_shape.disabled or not is_attacking:
		_hit_ids.clear()
		return
	for body in hitbox.get_overlapping_bodies():
		_try_hit(body)

func _on_hitbox_body_entered(body: Node2D) -> void:
	_try_hit(body)

func _try_hit(body: Node) -> void:
	if hitbox_shape.disabled or not is_attacking:
		return
	if body == self or not body.has_method("take_damage"):
		return
	var id := body.get_instance_id()
	if _hit_ids.has(id):
		return
	_hit_ids.append(id)
	body.take_damage(current_attack_damage, _facing)

func take_damage(amount: float, attacker_facing: float) -> void:
	knockback_multiplier += KNOCKBACK_MULTIPLIER_PER_HIT
	if is_attacking:
		finish_attack()
	hitbox_shape.disabled = true
	anim_player.stop()

	var launch_scale := knockback_multiplier * (amount / 10.0)
	var direction := attacker_facing if attacker_facing != 0.0 else _facing
	velocity = Vector2(direction * BASE_KNOCKBACK_X * launch_scale, -BASE_KNOCKBACK_Y * launch_scale)
	_in_knockback = true
	_lunging = false
	_lunge_time = 0.0
	_hitstun = 0.18 + 0.06 * knockback_multiplier
	_flash_white()

func _flash_white() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_set_flash(1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(HIT_FLASH_TIME)
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, HIT_FLASH_TIME)
	_flash_tween.tween_method(_set_flash, 0.0, 1.0, 0.0)
	_flash_tween.tween_interval(HIT_FLASH_TIME)
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, HIT_FLASH_TIME)

func _set_flash(value: float) -> void:
	modulate = _base_modulate
	if _sprite.material is ShaderMaterial:
		(_sprite.material as ShaderMaterial).set_shader_parameter("flash", value)

func _is_off_stage() -> bool:
	return position.x < BLAST_LEFT or position.x > BLAST_RIGHT or position.y < BLAST_TOP or position.y > BLAST_BOTTOM

func _respawn() -> void:
	if is_attacking:
		finish_attack()
	if _flash_tween:
		_flash_tween.kill()
	anim_player.stop()
	hitbox_shape.disabled = true
	_hit_ids.clear()
	velocity = Vector2.ZERO
	_lunging = false
	_lunge_time = 0.0
	_in_knockback = false
	_hitstun = 0.0
	knockback_multiplier = 1.0
	_facing = 1.0 if player_id == 1 else -1.0
	_sprite.flip_h = _facing < 0.0
	_set_flash(0.0)
	global_position = RESPAWN_POSITION
