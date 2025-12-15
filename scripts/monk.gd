extends Character

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	
	var mouse_pos = get_global_mouse_position()
	
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true 
	else:
		animated_sprite_2d.flip_h = false 

	play_anim("heal")
	
func _on_animation_finished():
	if animated_sprite_2d.animation == "heal":
		is_attacking = false
