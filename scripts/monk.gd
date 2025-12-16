extends Character

@export var heal_amount = 30
@export var heal_cooldown_duration = 5.0

var can_heal = true

func start_attack():
	# If we are cooling down or already attacking, stop.
	if not can_heal or is_attacking:
		return

	is_attacking = true
	velocity = Vector2.ZERO
	
	# 1. FACE MOUSE
	var mouse_pos = get_global_mouse_position()
	animated_sprite_2d.flip_h = (mouse_pos.x < global_position.x)

	# 2. PLAY ANIMATION
	play_anim("heal")
	
	# 3. WAIT FOR CAST POINT
	await get_tree().create_timer(0.2).timeout
	
	perform_heal()

func perform_heal():
	print("Monk cast Heal!")

	# 2. SEND TO MANAGER
	# We assume the parent of the Monk is the PartyManager
	var manager = get_parent()
	if manager.has_method("queue_heal_for_next_switch"):
		manager.queue_heal_for_next_switch(heal_amount)
	
	# 3. START COOLDOWN
	start_cooldown()

func start_cooldown():
	can_heal = false
	
	await get_tree().create_timer(heal_cooldown_duration).timeout
	
	can_heal = true
	print("Monk heal ready!")

func _on_animation_finished():
	if animated_sprite_2d.animation == "heal":
		is_attacking = false
