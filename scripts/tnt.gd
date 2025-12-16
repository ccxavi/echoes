extends Enemy 
class_name BombThrower

@export var bomb_scene: PackedScene 

@export var retreat_distance = 150.0 # If player is closer than this, run away
@export var throw_distance = 350.0   # The ideal range to stop and throw

func _ready():
	super._ready()
	
	stop_distance = throw_distance
	speed = 80.0
	max_hp = 30
	
	hp = max_hp

# We must override this to add the "Run Away" logic
func _physics_process(delta: float) -> void:
	# A. BASE LOGIC (Knockback & Burn) - Copied from Base because we are overriding
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity = knockback_velocity
		move_and_slide()
		return 
	
	if is_burning:
		_process_burn(delta)

	if not can_attack:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# B. TARGETING
	var target = get_active_player()
	if target == null:
		idle_behavior()
		return

	var dist = global_position.distance_to(target.global_position)

	# C. RANGED MOVEMENT LOGIC (The New Part)
	
	# 1. TOO CLOSE? -> RUN AWAY
	if dist < retreat_distance:
		run_away_from_target(target)
		
	# 2. IN RANGE? -> STOP AND ATTACK
	elif dist <= stop_distance:
		velocity = Vector2.ZERO
		
		if can_attack: 
			start_attack_sequence(target)
		else:
			# Face the player even while waiting on cooldown
			var dir_to_player = global_position.direction_to(target.global_position)
			face_direction(dir_to_player.x)
			if animated_sprite_2d.animation != "attack":
				play_anim("idle")
				
	# 3. TOO FAR? -> CHASE
	elif dist < detection_range:
		chase_target(target)
	else:
		idle_behavior()

func run_away_from_target(target: Node2D):
	# Calculate direction AWAY from player
	var direction = target.global_position.direction_to(global_position)
	var final_velocity = direction * speed
	
	# Apply separation force so enemies don't stack on top of each other while fleeing
	final_velocity += get_separation_force()
	
	velocity = final_velocity
	move_and_slide()
	
	play_anim("run")
	
	# Visual Choice: 
	# Option A: Face the direction we are running (looks like running away)
	face_direction(direction.x) 
	
	# Option B: Face the player while backing up (looks like strafing)
	# face_direction(-direction.x) 

# --- ATTACK LOGIC ---
func start_attack_sequence(target_node = null):
	can_attack = false
	
	if target_node:
		var dir = global_position.direction_to(target_node.global_position)
		face_direction(dir.x)
	
	play_anim("attack")
	
	# Wait for throw frame
	await get_tree().create_timer(0.3).timeout
	
	# Spawn Bomb
	if bomb_scene and target_node:
		var bomb = bomb_scene.instantiate()
		get_tree().current_scene.add_child(bomb)
		var spawn_pos = global_position + (target_node.global_position - global_position).normalized() * 20
		bomb.start(spawn_pos, target_node.global_position)
		AudioManager.play_sfx("tnt_throw", 0.1)
		
	
	# Prevent Animation Freeze Logic
	if animated_sprite_2d.animation == "attack" and animated_sprite_2d.is_playing():
		await animated_sprite_2d.animation_finished
		
	play_anim("idle")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
