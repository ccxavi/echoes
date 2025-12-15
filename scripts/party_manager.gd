extends Node2D

var characters: Array = []
var active_character_index: int = 0
var is_switching = false 

# Cooldown and Speed settings
var can_switch = true
const SWITCH_COOLDOWN = 2.0
const onCharacterSwitchSpeed = 0.3

@onready var camera: Camera2D = %Camera2D
@onready var switch_vfx: AnimatedSprite2D = $switch_vfx

func _ready():
	switch_vfx.visible = false 
	
	# Populate the characters array
	for child in get_children():
		if child is CharacterBody2D:
			characters.append(child)
	
	# Activate the first one (Index 0), deactivate the rest
	for i in range(characters.size()):
		if i == 0: activate_character(characters[i])
		else: deactivate_character(characters[i])

func _unhandled_input(_event):
	# We ONLY use this to block inputs during switching.
	# The actual "1 2 3 4" detection happens in the Echo Deck script!
	if is_switching or not can_switch:
		get_viewport().set_input_as_handled()

# --- THIS IS THE KEY FUNCTION ---
# This runs when the Echo Deck sends the "switch_requested" signal
func _on_echo_deck_switch_requested(character_identifier):
	print("Signal received! Requested: ", character_identifier)
	
	var target_index = -1
	
	# 1. Match by Name (String) - e.g. "Warrior"
	if typeof(character_identifier) == TYPE_STRING:
		for i in range(characters.size()):
			if characters[i].name == character_identifier:
				target_index = i
				break
	
	# 2. Match by Number (Int) - e.g. 0, 1, 2, 3
	elif typeof(character_identifier) == TYPE_INT:
		target_index = character_identifier

	# Perform the switch if valid
	if target_index != -1:
		perform_switch_to_index(target_index)

# --- CORE SWITCHING LOGIC ---
func perform_switch_to_index(target_index: int):
	# Guard Clauses
	if is_switching or not can_switch: return
	if target_index == active_character_index: return
	
	is_switching = true 
	can_switch = false 
	
	var old_char = characters[active_character_index]
	
	# Play VFX
	play_vfx(old_char.global_position)
	
	# Hide Old Character
	if old_char.has_node("main_sprite"):
		old_char.get_node("main_sprite").visible = false
	
	# Calculate Duration
	var duration = 0.5
	if switch_vfx.sprite_frames.has_animation("switch"):
		var frames = switch_vfx.sprite_frames.get_frame_count("switch")
		var fps = switch_vfx.sprite_frames.get_animation_speed("switch")
		if fps > 0: duration = frames / fps
	
	# UPDATE INDEX
	active_character_index = target_index
	var new_char = characters[active_character_index]
	
	# Move new char to old char's position
	new_char.global_position = old_char.global_position
	
	deactivate_character(old_char)
	activate_character(new_char)
	
	# Apply Slow Speed
	var original_speed = 0.0
	if "speed" in new_char:
		original_speed = new_char.speed
		new_char.speed = original_speed * onCharacterSwitchSpeed
	
	# Handle Sprite Visibility (Smoke effect)
	if new_char.has_node("main_sprite"):
		new_char.get_node("main_sprite").visible = false
		await get_tree().create_timer(duration * 0.5).timeout
		new_char.get_node("main_sprite").visible = true
	else:
		await get_tree().create_timer(duration * 0.5).timeout
	
	# Restore Speed
	if "speed" in new_char:
		new_char.speed = original_speed
		
	switch_vfx.visible = false
	is_switching = false 
	
	# Cooldown
	await get_tree().create_timer(SWITCH_COOLDOWN).timeout
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
