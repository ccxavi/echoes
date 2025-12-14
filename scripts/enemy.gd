class_name Enemy extends CharacterBody2D

@export var speed = 100.0           # Movement speed in pixels/sec
@export var detection_range = 200.0 # Max distance to start chasing
@export var stop_distance = 20.0    # buffer zone to stop before hitting player

@export var separation_force = 50.0 # Strength of repulsion from other enemies

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $hitbox

func _ready():
	if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(_delta: float) -> void:
	# --- 1. FIND ACTIVE TARGET ---
	var players = get_tree().get_nodes_in_group("player")
	var target = null
	
	for p in players:
		if p.visible:
			target = p
			break
			
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		play_anim("idle")
		return

	# --- 2. CALCULATE CHASE VELOCITY ---
	var direction = global_position.direction_to(target.global_position)
	var distance = global_position.distance_to(target.global_position)
	var final_velocity = Vector2.ZERO
	
	if distance < detection_range and distance > stop_distance:
		final_velocity = direction * speed
		play_anim("run")
	else:
		play_anim("idle")
		
	# --- 3. ADD SEPARATION (Anti-Stacking Logic) ---
	# We push the enemy away from nearby allies so they don't blob up
	var separation = Vector2.ZERO
	var neighbors = get_tree().get_nodes_in_group("enemy")
	
	for neighbor in neighbors:
		# Don't check against self, and only check close neighbors (e.g. within 30px)
		if neighbor != self and global_position.distance_to(neighbor.global_position) < 30:
			var push_dir = (global_position - neighbor.global_position).normalized()
			separation += push_dir * separation_force
	
	# Combine chase movement + separation push
	velocity = final_velocity + separation

	# --- 4. FACE THE PLAYER ---
	if direction.x < 0:
		animated_sprite_2d.flip_h = true
	elif direction.x > 0:
		animated_sprite_2d.flip_h = false

	# --- 5. APPLY PHYSICS ---
	move_and_slide()

# --- HITBOX DETECTION ---
func _on_hitbox_body_entered(body: Node2D):
	if body.is_in_group("player"):
		print("Collide! Player passed through me.")

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)
