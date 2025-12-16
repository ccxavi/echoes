extends Character

# --- CONFIGURATION ---
@export_group("Dash")
@export var dash_speed = 600.0
@export var dash_duration = 0.2
@export var dash_cooldown = 1.0

@export var fire_damage = 2
@export var damage_time = 4.0 # do fire_damage every 4 seconds


# --- STATE ---
var is_dashing = false
var can_dash = true

func _physics_process(delta: float) -> void:
	# 1. DASH BEHAVIOR (Override Normal Movement)
	if is_dashing:
		# VFX: Spawn a ghost trail every 4 physics frames
		if Engine.get_physics_frames() % 4 == 0:
			spawn_dash_ghost()
			
		move_and_slide()
		return # IMPORTANT: Skip the parent class physics!

	# 2. CHECK INPUT
	# Ensure "dash" is in your Input Map (Project Settings > Input Map)
	if Input.is_action_just_pressed("dash") and can_dash:
		start_dash()
		return

	# 3. NORMAL MOVEMENT
	# If we aren't dashing, run the standard character logic
	super._physics_process(delta)

func start_dash():
	# A. Determine Direction
	# We try to use current input first. If no input, use facing direction.
	var move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dash_dir = move_input
	
	if dash_dir == Vector2.ZERO:
		# Fallback: Dash the way we are looking
		dash_dir = Vector2.LEFT if animated_sprite_2d.flip_h else Vector2.RIGHT
	
	# B. Set State
	is_dashing = true
	can_dash = false
	velocity = dash_dir.normalized() * dash_speed
	
	# VFX: Tint the goblin Blue/Cyan to show speed
	var original_modulate = modulate
	modulate = Color(0.5, 1, 1) 
	
	# C. Dash Duration
	await get_tree().create_timer(dash_duration).timeout
	
	# D. Cleanup
	is_dashing = false
	velocity = Vector2.ZERO # Optional: Stop sliding immediately
	modulate = original_modulate # Reset color
	
	# E. Cooldown
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true

# --- VFX HELPER: GHOST TRAIL ---
func spawn_dash_ghost():
	# 1. Create a simple Sprite2D copy
	var ghost = Sprite2D.new()
	# Grab the exact texture frame currently being played
	var texture = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame)
	
	ghost.texture = texture
	ghost.global_position = global_position
	ghost.flip_h = animated_sprite_2d.flip_h
	ghost.modulate = Color(18.892, 10.667, 11.092, 0.384) # Transparent Cyan
	ghost.z_index = 5 # Render BEHIND the player
	
	# 2. Add to scene (Root of the scene, not the player, so it doesn't move with us)
	get_tree().current_scene.add_child(ghost)
	
	# 3. Animate Fade Out
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3) # Fade alpha to 0 over 0.3s
	tween.tween_callback(ghost.queue_free) # Delete when done

func start_attack():
	# 1. Setup State (Same as parent)
	is_attacking = true
	velocity = Vector2.ZERO 
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	# 2. Rotate & Animate (Same as parent)
	weapon_pivot.look_at(mouse_pos)
	play_attack_animation(diff) # Defined in parent, we can reuse it
	
	# 3. Wait for impact frame
	await get_tree().create_timer(0.2).timeout
	
	# 4. FIRE ATTACK LOGIC
	# Unlike parent: No Crit, No Knockback, Just Burn.
	var bodies = attack_area.get_overlapping_bodies()
	
	for body in bodies:
		if body.is_in_group("enemy"):
			if body.has_method("apply_burn"):
				body.apply_burn(fire_damage, damage_time) 
				print("Applied Burn to ", body.name)
