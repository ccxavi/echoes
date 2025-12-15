extends Node2D

var characters: Array = []
var active_character_index: int = 0
var is_switching = false 

# New variable to track the cooldown state
var can_switch = true
const SWITCH_COOLDOWN = 2
const onCharacterSwitchSpeed = 0.3

@onready var camera: Camera2D = %Camera2D
@onready var switch_vfx: AnimatedSprite2D = $switch_vfx

func _ready():
	switch_vfx.visible = false 
	
	for child in get_children():
		if child is CharacterBody2D:
			characters.append(child)
	
	for i in range(characters.size()):
		if i == 0: activate_character(characters[i])
		else: deactivate_character(characters[i])

func _unhandled_input(event):
	# Block input if we are currently animating OR if we are on cooldown
	if is_switching or not can_switch:
		return

	if event.is_action_pressed("switch_next"):
		perform_switch(1) 
	elif event.is_action_pressed("switch_prev"):
		perform_switch(-1) 

func perform_switch(direction: int):
	is_switching = true 
	can_switch = false # Lock the cooldown immediately
	
	var old_char = characters[active_character_index]
	
	# 1. Play VFX
	play_vfx(old_char.global_position)
	
	# 2. Hide Old Character
	if old_char.has_node("main_sprite"):
		old_char.get_node("main_sprite").visible = false
	
	# 3. Calculate Duration
	var duration = 0.5
	if switch_vfx.sprite_frames.has_animation("switch"):
		var frames = switch_vfx.sprite_frames.get_frame_count("switch")
		var fps = switch_vfx.sprite_frames.get_animation_speed("switch")
		if fps > 0: duration = frames / fps
	
	# 4. SWAP MATH
	active_character_index = (active_character_index + direction + characters.size()) % characters.size()
	
	var new_char = characters[active_character_index]
	new_char.global_position = old_char.global_position
	
	deactivate_character(old_char)
	activate_character(new_char)
	
	# 5. Apply Slow Speed
	var original_speed = new_char.speed
	new_char.speed = original_speed * onCharacterSwitchSpeed
	
	# 6. Hide New Sprite & Wait
	if new_char.has_node("main_sprite"):
		new_char.get_node("main_sprite").visible = false
		
		# Wait for half the smoke animation
		await get_tree().create_timer(duration * 0.5).timeout
		
		new_char.get_node("main_sprite").visible = true
	
	# 7. Restore Speed & Cleanup
	new_char.speed = original_speed
	switch_vfx.visible = false
	
	# Unlock the PHYSICS/MOVEMENT immediately so player can walk
	is_switching = false
	
	# 8. COOLDOWN TIMER
	# Start the 0.5s timer only after the switch is fully done
	await get_tree().create_timer(SWITCH_COOLDOWN).timeout
	
	# Allow switching again
	can_switch = true

func play_vfx(pos: Vector2):
	switch_vfx.global_position = pos
	switch_vfx.visible = true
	switch_vfx.play("switch")
	switch_vfx.frame = 0 

func activate_character(char_node):
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
