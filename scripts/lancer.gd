extends Character

# Override the base function to use 8-Directional Logic
func play_attack_animation(diff: Vector2):
	var angle = diff.angle()
	var snapped_angle = snapped(angle, PI / 4.0)
	var octant = int(round(snapped_angle / (PI / 4.0)))
	
	match octant:
		0: # Right
			play_anim("attack_side")
			animated_sprite_2d.flip_h = false
		1: # Down-Right
			play_anim("attack_down_diag")
			animated_sprite_2d.flip_h = false
		2: # Down
			play_anim("attack_down")
		3: # Down-Left
			play_anim("attack_down_diag")
			animated_sprite_2d.flip_h = true 
		4, -4: # Left
			play_anim("attack_side")
			animated_sprite_2d.flip_h = true 
		-3: # Up-Left
			play_anim("attack_up_diag")
			animated_sprite_2d.flip_h = true 
		-2: # Up
			play_anim("attack_up")
		-1: # Up-Right
			play_anim("attack_up_diag")
			animated_sprite_2d.flip_h = false
