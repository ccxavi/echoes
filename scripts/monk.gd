extends Character

# We override the entire start_attack function.
# This bypasses the Base Class logic (Hitbox rotation, Damage dealing).
func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	
	# 1. FACE MOUSE (Simple Left/Right)
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true 
	else:
		animated_sprite_2d.flip_h = false 

	# 2. PLAY ANIMATION
	play_anim("heal")
	
	# 3. HEAL LOGIC
	# Wait for the "cast" point (e.g. 0.2s or 0.5s)
	await get_tree().create_timer(0.2).timeout
	
	perform_heal()

func perform_heal():
	print("Monk cast Heal!")
	# Add your actual healing code here
	# Example: Heal self
	# hp = min(hp + 10, max_hp)
	
	# Example: Spawn a healing particle effect?
	# var effect = heal_vfx.instantiate()
	# add_child(effect)

# Override the cleanup function to catch "heal"
func _on_animation_finished():
	if animated_sprite_2d.animation == "heal":
		is_attacking = false
	
	# If you have other shared animations (like "run"), you can optionally call:
	# super._on_animation_finished()
