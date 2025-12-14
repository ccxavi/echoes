extends CharacterBody2D

@export var speed = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta):
	# --- 1. MOVEMENT (Keyboard) ---
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	# --- 2. FACING (Mouse) ---
	# We check where the mouse is relative to the player
	var mouse_pos = get_global_mouse_position()
	
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true  # Mouse is to the left -> Face Left
	else:
		animated_sprite_2d.flip_h = false # Mouse is to the right -> Face Right

	# --- 3. ANIMATION STATE ---
	# We still only play "run" if we are actually moving
	if direction != Vector2.ZERO:
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")

	# --- 4. APPLY PHYSICS ---
	move_and_slide()
