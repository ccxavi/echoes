extends Node2D

var characters: Array = []
var active_character_index: int = 0
var is_switching = false 

var can_switch = true
const SWITCH_COOLDOWN = 1
const onCharacterSwitchSpeed = 0.3

var queued_heal_amount: int = 0 # Stores the heal from the monk

@onready var camera: Camera2D = %Camera2D
@onready var switch_vfx: AnimatedSprite2D = $switch_vfx

func _ready():
	switch_vfx.visible = false 
	
	for child in get_children():
		if child is CharacterBody2D:
			characters.append(child)
			
			# Listen for death signals
			if child.has_signal("character_died"):
				child.character_died.connect(_on_character_died)
	
	for i in range(characters.size()):
		if i == 0: activate_character(characters[i])
		else: deactivate_character(characters[i])

func _unhandled_input(event):
	if is_switching or not can_switch:
		return

	if event.is_action_pressed("switch_1"):
		try_switch_to_index(0)
	elif event.is_action_pressed("switch_2"):
		try_switch_to_index(1)
	elif event.is_action_pressed("switch_3"):
		try_switch_to_index(2)
	elif event.is_action_pressed("switch_4"):
		try_switch_to_index(3)

func try_switch_to_index(target_index: int):
	if target_index >= characters.size():
		return 
		
	if target_index == active_character_index:
		return 
	
	if characters[target_index].is_dead: # check if deads
		print("Character not available (Dead)")
		return

	perform_switch(target_index)

func _on_character_died(_dead_char_node):
	# We just need to find the next living person.
	var next_alive_index = -1
	
	# Loop through list to find someone alive
	# We start from current index + 1 and wrap around
	for i in range(1, characters.size()):
		var check_index = (active_character_index + i) % characters.size()
		if not characters[check_index].is_dead:
			next_alive_index = check_index
			break
	
	if next_alive_index != -1:
		print("Switching to next survivor: ", characters[next_alive_index].name)
		# Force the switch (bypass cooldowns/input checks)
		perform_switch(next_alive_index)
	else:
		print("GAME OVER - All characters are dead")
		# Handle Game Over screen here

func perform_switch(target_index: int):
	is_switching = true 
	can_switch = false 
	
	var old_char = characters[active_character_index]
	
	# 1. Play VFX (at old char position - works even if they just died)
	play_vfx(old_char.global_position)
	
	# 2. Hide Old Character
	# (If they died, they are already hidden, but this double check is fine)
	if old_char.has_node("main_sprite"):
		old_char.get_node("main_sprite").visible = false
	
	# 3. Calculate Duration
	var duration = 0.5
	if switch_vfx.sprite_frames.has_animation("switch"):
		var frames = switch_vfx.sprite_frames.get_frame_count("switch")
		var fps = switch_vfx.sprite_frames.get_animation_speed("switch")
		if fps > 0: duration = frames / fps
	
	# 4. SWAP LOGIC
	active_character_index = target_index
	
	var new_char = characters[active_character_index]
	new_char.global_position = old_char.global_position
	
	deactivate_character(old_char)
	activate_character(new_char)
	
	if new_char.has_method("start_invulnerability"):
		new_char.start_invulnerability(false)
	
	# 5. Apply Slow Speed
	var original_speed = new_char.speed
	new_char.speed = original_speed * onCharacterSwitchSpeed
	
	# 6. Hide New Sprite & Wait
	if new_char.has_node("main_sprite"):
		new_char.get_node("main_sprite").visible = false
		await get_tree().create_timer(duration * 0.5).timeout
		new_char.get_node("main_sprite").visible = true
	
	# 7. Restore Speed & Cleanup
	new_char.speed = original_speed
	switch_vfx.visible = false
	
	# --- APPLY QUEUED HEAL ---
	if queued_heal_amount > 0:
		# We wait a tiny bit so the character is visible before healing
		await get_tree().create_timer(0.1).timeout
		if new_char.has_method("receive_heal"):
			new_char.receive_heal(queued_heal_amount)
		
		# Reset the bank
		queued_heal_amount = 0
	
	is_switching = false
	
	await get_tree().create_timer(SWITCH_COOLDOWN).timeout
	can_switch = true

func play_vfx(pos: Vector2):
	switch_vfx.global_position = pos
	switch_vfx.visible = true
	switch_vfx.play("switch")
	switch_vfx.frame = 0 

func activate_character(char_node):
	# Don't activate if dead (Sanity check)
	if char_node.is_dead: return
	
	char_node.visible = true
	if char_node.has_node("main_sprite"):
		char_node.get_node("main_sprite").visible = true
		
	char_node.set_process_unhandled_input(true)
	char_node.set_physics_process(true)
	char_node.process_mode = Node.PROCESS_MODE_INHERIT
	if camera: camera.target = char_node

func deactivate_character(char_node):
	char_node.visible = false
	char_node.set_process_unhandled_input(false)
	char_node.set_physics_process(false)
	char_node.process_mode = Node.PROCESS_MODE_DISABLED

# The Monk calls this function
func queue_heal_for_next_switch(amount: int):
	queued_heal_amount = amount
	print("Heal queued! Switch to another character to receive it.")
