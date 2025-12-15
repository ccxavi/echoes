class_name Character extends CharacterBody2D

@export var speed = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $main_sprite

# Only used for Combat now. Switching is handled by PartyManager disabling us.
var is_attacking = false

func _ready():
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	# 1. PRIORITY CHECK: If attacking, don't move
	if is_attacking:
		return 

	# 2. ATTACK INPUT
	if Input.is_action_just_pressed("attack"): 
		start_attack()
		return 

	# 3. MOVEMENT
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	# 4. FACING
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true 
	else:
		animated_sprite_2d.flip_h = false 

	# 5. ANIMATION
	if direction != Vector2.ZERO:
		play_anim("run")
	else:
		play_anim("idle")

	# 6. PHYSICS
	move_and_slide()

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO 
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	if abs(diff.y) > abs(diff.x):
		if diff.y < 0: play_anim("attack_up")
		else: play_anim("attack_down")
	else:
		play_anim("attack_side")
		animated_sprite_2d.flip_h = (diff.x < 0)

func _on_animation_finished():
	# Only unlock if we were attacking. 
	# (Movement anims like 'run' don't lock us, so we don't care about them finishing)
	if animated_sprite_2d.animation in ["attack_side", "attack_up", "attack_down"]:
		is_attacking = false
