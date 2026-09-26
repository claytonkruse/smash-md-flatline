extends CharacterBody2D

#references
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $Hitbox
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

#attack variables
var is_attacking: bool = false
var current_attack_damage: float = 10.0 #placeholder

#movement variables
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

#connects hitbox to damage function
func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_body_entered)

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
		
	if not is_on_floor():
		if _sprite.is_playing():
			_sprite.pause()
		return

	var anim := &"surgeon_unarmed_idle"
	if direction > 0.0:
		anim = &"surgeon_unarmed_walk"
	elif direction < 0.0:
		anim = &"surgeon_unarmed_walk_backward"

	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)

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
