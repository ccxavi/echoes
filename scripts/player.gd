class_name Character extends CharacterBody2D

@export var speed = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $main_sprite
@onready var effects_sprite: AnimatedSprite2D = $sfx

var is_attacking = false

func _ready():
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	effects_sprite.animation_finished.connect(_on_effect_finished)
	
	# Hide the smoke effect at the start
	effects_sprite.visible = false

func _physics_process(_delta):
	# If we are attacking/switching, don't move
	if is_attacking:
		return 

	# --- 2. ATTACK INPUT ---
	if Input.is_action_just_pressed("attack"): 
		start_attack()
		return # Stop processing movement for this frame

	# --- 3. MOVEMENT (Keyboard) ---
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	# --- 4. FACING (Mouse) ---
	var mouse_pos = get_global_mouse_position()
	
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true 
	else:
		animated_sprite_2d.flip_h = false 

	# --- 5. RUN/IDLE ANIMATION ---
	if direction != Vector2.ZERO:
		play_anim("run")
	else:
		play_anim("idle")

	# --- 6. APPLY PHYSICS ---
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
		if diff.y < 0:
			play_anim("attack_up")
		else:
			play_anim("attack_down")
	else:
		play_anim("attack_side")
		if diff.x < 0:
			animated_sprite_2d.flip_h = true
		else:
			animated_sprite_2d.flip_h = false

func play_switch_anim():
	is_attacking = true
	velocity = Vector2.ZERO
	
	# Play the shared smoke effect
	effects_sprite.visible = true
	effects_sprite.play("switch")
	
	play_anim("idle")

func _on_animation_finished():
	if animated_sprite_2d.animation in ["attack_side", "attack_up", "attack_down"]:
		is_attacking = false

func _on_effect_finished():
	if effects_sprite.animation == "switch":
		effects_sprite.visible = false
		is_attacking = false
