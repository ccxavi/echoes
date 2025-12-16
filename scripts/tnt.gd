extends Enemy 
class_name BombThrower

@export var bomb_scene: PackedScene 

@export var retreat_distance = 150.0 # If player is closer than this, run away
@export var throw_distance = 350.0   # The ideal range to stop and throw

func _ready():
	super._ready()
	
	# Override Base Stats
	stop_distance = throw_distance
	speed = 80.0
	max_hp = 30
	hp = max_hp
	
	# Set inherited detection range if needed, or keep base default
	# detection_range = 500.0 

# We must override this to add the "Run Away" logic AND the "Memory" logic
func _physics_process(delta: float) -> void:
	if footstep_timer > 0:
		footstep_timer -= delta

	# A. BASE LOGIC (Knockback & Burn)
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity = knockback_velocity
		move_and_slide()
		return 
	
	if is_burning:
		_process_burn(delta)
	
	# B. WAIT FOR ANIMATIONS (Alert "!" or Confusion "?")
	if is_reacting or is_confused:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not can_attack:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# C. TARGETING & AI DECISION
	var target = get_active_player()
	var dist = 99999.0
	var has_los = false
	
	if target:
		dist = global_position.distance_to(target.global_position)
		has_los = can_see_target(target)

	# --- CASE 1: Player is Visible (or very close) ---
	# We treat "too close" as visible automatically to prevent Raycast bugs at 0 range
	if target and dist < detection_range and (has_los or dist < 50.0):
		
		# 1. Alert (Surprise!)
		if not is_alerted:
			start_alert_sequence(target)
			return

		# 2. Update Memory
		last_known_pos = target.global_position

		# 3. RANGED BEHAVIOR (The Logic Split)
		if dist < retreat_distance:
			# Too close! Run away!
			run_away_from_target(target)
			
		elif dist <= stop_distance:
			# Perfect range. Stop and Throw.
			velocity = Vector2.ZERO
			
			if can_attack: 
				start_attack_sequence(target)
			else:
				# Face player while waiting on cooldown
				var dir = global_position.direction_to(target.global_position)
				face_direction(dir.x)
				if animated_sprite_2d.animation != "attack":
					play_anim("idle")
		else:
			# Visible but too far to throw -> Chase normally
			move_to_position(target.global_position)
			
	# --- CASE 2: Player Not Visible, but we have Memory ---
	elif last_known_pos != null:
		var dist_to_memory = global_position.distance_to(last_known_pos)
		
		if dist_to_memory > 10.0:
			# Move to where we last saw them
			move_to_position(last_known_pos)
		else:
			# Arrived at memory, nobody here. Get Confused.
			start_confusion_sequence()
			
	# --- CASE 3: Idle ---
	else:
		if is_alerted: is_alerted = false
		idle_behavior()

# --- HELPER: RETREAT ---
func run_away_from_target(target: Node2D):
	# Calculate direction AWAY from player
	var direction = target.global_position.direction_to(global_position)
	var final_velocity = direction * speed
	
	# Apply separation so enemies don't stack
	final_velocity += get_separation_force()
	
	velocity = final_velocity
	move_and_slide()
	
	play_anim("run")
	
	# Handle Footsteps
	if footstep_timer <= 0:
		AudioManager.play_sfx("grass", 0.1, -20.0)
		footstep_timer = FOOTSTEP_INTERVAL
	
	# Visual: Face the direction we are running
	face_direction(direction.x) 

# --- ATTACK OVERRIDE ---
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
		
		# Spawn slightly in front
		var spawn_pos = global_position + (target_node.global_position - global_position).normalized() * 20
		bomb.start(spawn_pos, target_node.global_position)
		
		AudioManager.play_sfx("tnt_throw", 0.1)
	
	# Wait for animation
	if animated_sprite_2d.animation == "attack" and animated_sprite_2d.is_playing():
		await animated_sprite_2d.animation_finished
		
	play_anim("idle")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
