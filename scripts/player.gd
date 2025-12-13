extends CharacterBody2D

@export var speed = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta):
	# 1. Get Input Direction
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 2. Apply Speed
	velocity = direction * speed

	# 3. Animation Logic
	if direction != Vector2.ZERO:
		# Player is moving
		animated_sprite_2d.play("run")
		
		# Flip Sprite Logic
		if direction.x < 0:
			animated_sprite_2d.flip_h = true  # Face Left
		elif direction.x > 0:
			animated_sprite_2d.flip_h = false # Face Right
	else:
		# Player is standing still
		# If you have an "idle" animation, change "default" to "idle"
		animated_sprite_2d.play("idle") 

	# 4. Move
	move_and_slide()
