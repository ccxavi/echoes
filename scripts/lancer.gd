extends Character

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	var angle = diff.angle()
	var snapped_angle = snapped(angle, PI / 4.0)
	
	# Convert radians to simple integer steps (-4 to 4)
	# 0 = Right, 2 = Down, -2 = Up, 4/-4 = Left
	var octant = int(round(snapped_angle / (PI / 4.0)))
	
	match octant:
		0: # Right (0 degrees)
			play_anim("attack_side")
			animated_sprite_2d.flip_h = false
		1: # Down-Right (45 degrees)
			play_anim("attack_down_diag")
			animated_sprite_2d.flip_h = false
		2: # Down (90 degrees)
			play_anim("attack_down")
			# flip_h doesn't matter for pure down, usually
		3: # Down-Left (135 degrees)
			play_anim("attack_down_diag")
			animated_sprite_2d.flip_h = true # <--- FLIP!
		4, -4: # Left (180/-180 degrees)
			play_anim("attack_side")
			animated_sprite_2d.flip_h = true # <--- FLIP!
		-3: # Up-Left (-135 degrees)
			play_anim("attack_up_diag")
			animated_sprite_2d.flip_h = true # <--- FLIP!
		-2: # Up (-90 degrees)
			play_anim("attack_up")
		-1: # Up-Right (-45 degrees)
			play_anim("attack_up_diag")
			animated_sprite_2d.flip_h = false

func _on_animation_finished():
	if animated_sprite_2d.animation in ["attack_side", "attack_up", "attack_down", "attack_up_diag", "attack_down_diag"]:
		is_attacking = false
