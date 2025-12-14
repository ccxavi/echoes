extends Node2D

var characters: Array = []
var active_character_index: int = 0
var is_switching = false 
const onCharacterSwitchSpeed = 0.3

@onready var camera: Camera2D = %Camera2D
@onready var switch_vfx: AnimatedSprite2D = $switch_vfx

func _ready():
	switch_vfx.visible = false # Hide smoke at start
	
	# Get all Character children (ignores the VFX node)
	for child in get_children():
		if child is CharacterBody2D:
			characters.append(child)
	
	# Enable first character, disable others
	for i in range(characters.size()):
		if i == 0: activate_character(characters[i])
		else: deactivate_character(characters[i])

func _unhandled_input(event):
	if event.is_action_pressed("switch_next") and not is_switching:
		switch_to_next()

func switch_to_next():
	is_switching = true 
	var old_char = characters[active_character_index]
	
	# play vfx
	play_vfx(old_char.global_position)
	
	# hide old character
	if old_char.has_node("main_sprite"):
		old_char.get_node("main_sprite").visible = false
	
	# calculate duration
	var duration = 0.5
	if switch_vfx.sprite_frames.has_animation("switch"):
		var frames = switch_vfx.sprite_frames.get_frame_count("switch")
		var fps = switch_vfx.sprite_frames.get_animation_speed("switch")
		if fps > 0: duration = frames / fps
	
	# swap logic
	active_character_index = (active_character_index + 1) % characters.size()
	var new_char = characters[active_character_index]
	
	new_char.global_position = old_char.global_position
	
	deactivate_character(old_char)
	activate_character(new_char)
	
	# apply character speed during animation
	var original_speed = new_char.speed
	new_char.speed = original_speed * onCharacterSwitchSpeed
	
	# hide new sprite & wait
	if new_char.has_node("main_sprite"):
		new_char.get_node("main_sprite").visible = false
		
		# wait for half the smoke animation
		await get_tree().create_timer(duration * 0.5).timeout
		
		new_char.get_node("main_sprite").visible = true
	
	# restore speed
	new_char.speed = original_speed
	
	# cleanup
	switch_vfx.visible = false
	is_switching = false

func play_vfx(pos: Vector2):
	switch_vfx.global_position = pos
	switch_vfx.visible = true
	switch_vfx.play("switch")
	switch_vfx.frame = 0 

func activate_character(char_node):
	char_node.visible = true
	# Force visibility reset just in case
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
