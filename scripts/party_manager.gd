extends Node2D

var characters: Array = []
var active_character_index: int = 0
var is_switching = false # prevent button spam
var wait_time = 0.6

@export var camera: Camera2D 

func _ready():
	characters = get_children()
	for i in range(characters.size()):
		if i == 0:
			activate_character(characters[i])
		else:
			deactivate_character(characters[i])

func _unhandled_input(event):
	# Check if we are already switching. If yes, ignore input.
	if event.is_action_pressed("switch_next") and not is_switching:
		switch_to_next()

func switch_to_next():
	is_switching = true 
	
	var old_char = characters[active_character_index]
	
	# Play animation on OLD character
	var duration = old_char.play_switch_anim()
	if duration != null and duration is float:
		wait_time = duration
	
	# Wait dynamically
	await get_tree().create_timer(wait_time).timeout
	
	# --- SWAP LOGIC ---
	active_character_index = (active_character_index + 1) % characters.size()
	var new_char = characters[active_character_index]
	
	new_char.global_position = old_char.global_position
	
	deactivate_character(old_char)
	activate_character(new_char)
	
	# Play animation on NEW character
	if new_char.has_method("play_switch_anim"):
		new_char.play_switch_anim()
		
	is_switching = false
	
func activate_character(char_node):
	char_node.visible = true
	
	# 1. Reset Body
	if char_node.has_node("AnimatedSprite2D"):
		char_node.get_node("AnimatedSprite2D").visible = true
		
	# 2. Reset Smoke (Stop any frozen frames)
	if char_node.has_node("sfx"):
		var sfx = char_node.get_node("sfx")
		sfx.visible = false
		sfx.stop()
		sfx.frame = 0
	
	# Standard activation stuff
	char_node.set_process_unhandled_input(true)
	char_node.set_physics_process(true)
	char_node.process_mode = Node.PROCESS_MODE_INHERIT
	
	if camera:
		camera.target = char_node

func deactivate_character(char_node):
	char_node.visible = false
	char_node.set_process_unhandled_input(false)
	char_node.set_physics_process(false)
	char_node.process_mode = Node.PROCESS_MODE_DISABLED
