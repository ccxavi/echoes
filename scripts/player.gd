extends CharacterBody2D

@export var speed = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# We need this to lock movement while attacking
var is_attacking = false

func _ready():
	# Connect the signal so we know when the sword swing ends
	# This is crucial! It tells the script "Okay, you can move again."
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	# 1. PRIORITY CHECK: If we are attacking, don't move or change animation
	if is_attacking:
		return 

	# --- 2. ATTACK INPUT ---
	if Input.is_action_just_pressed("attack"): # Make sure "attack" is in Input Map
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
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")

	# --- 6. APPLY PHYSICS ---
	move_and_slide()

# --- NEW ATTACK LOGIC ---
func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO # Stop moving when attacking (prevents sliding)
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	# Math: Check if the mouse is more "Vertical" or more "Horizontal"
	if abs(diff.y) > abs(diff.x):
		# Vertical Attack
		if diff.y < 0:
			animated_sprite_2d.play("attack_up")
		else:
			animated_sprite_2d.play("attack_down")
	else:
		# Horizontal Attack
		animated_sprite_2d.play("attack_side")
		# We still need to flip the sprite for side attacks
		if diff.x < 0:
			animated_sprite_2d.flip_h = true
		else:
			animated_sprite_2d.flip_h = false

# This function runs automatically when the animation ends
func _on_animation_finished():
	if is_attacking:
		is_attacking = false
		# The physics process will take over again in the next frame
