extends Node2D

var characters: Array = []
var active_character_index: int = 0
var is_switching = false 
var can_switch = true
const SWITCH_COOLDOWN = 1.0 
const onCharacterSwitchSpeed = 0.3
var queued_heal_amount: int = 0 

@onready var camera: Camera2D = %Camera2D
@onready var switch_vfx: AnimatedSprite2D = $switch_vfx
@export var echo_deck_ui: CanvasLayer 

func _ready():
	switch_vfx.visible = false 
	
	# 1. Setup Characters
	for child in get_children():
		if child is CharacterBody2D:
			characters.append(child)
			if child.has_signal("character_died"):
				child.character_died.connect(_on_character_died)
	
	for i in range(characters.size()):
		var char_node = characters[i]
		
		# Connect Health Signal
		if char_node.has_signal("health_changed"):
			char_node.health_changed.connect(_on_health_update_received.bind(i))
			# Send initial HP to UI
			if echo_deck_ui and "hp" in char_node:
				echo_deck_ui.call_deferred("update_character_health", i, char_node.hp, char_node.max_hp)
		
		# Connect Ability Signal
		if char_node.has_signal("ability_used"):
			char_node.ability_used.connect(_on_char_ability_used)

		# Set initial active state
		if i == 0: activate_character(characters[i])
		else: deactivate_character(characters[i])

	# 2. Setup UI Connections
	if echo_deck_ui:
		echo_deck_ui.switch_requested.connect(_on_ui_switch_requested)
		echo_deck_ui.skill_button_pressed.connect(_on_ui_skill_pressed)
		
		# Connect Stats Request
		if not echo_deck_ui.stats_requested.is_connected(_on_ui_stats_requested):
			echo_deck_ui.stats_requested.connect(_on_ui_stats_requested)
		
		echo_deck_ui.call_deferred("highlight_card", 0)
		if characters.size() > 0:
			update_ui_button_state(characters[0])

# --- NEW: Handle Stats Request ---
func _on_ui_stats_requested():
	# Send the character data array back to the UI
	echo_deck_ui.show_stats_screen(characters)

func _unhandled_input(event):
	if event.is_action_pressed("switch_1"): try_switch_to_index(0)
	elif event.is_action_pressed("switch_2"): try_switch_to_index(1)
	elif event.is_action_pressed("switch_3"): try_switch_to_index(2)
	elif event.is_action_pressed("switch_4"): try_switch_to_index(3)

# --- UI HANDLERS ---
func _on_ui_switch_requested(target_index):
	try_switch_to_index(target_index)

func _on_ui_skill_pressed():
	var active_char = characters[active_character_index]
	if active_char.has_method("try_use_special_ability"):
		active_char.try_use_special_ability()

func _on_health_update_received(current_hp, max_hp, index):
	if echo_deck_ui: echo_deck_ui.update_character_health(index, current_hp, max_hp)

func _on_char_ability_used(_time, max_time):
	if echo_deck_ui: echo_deck_ui.trigger_cooldown_animation(max_time)

# --- SWITCHING LOGIC ---
func try_switch_to_index(target_index: int):
	# Gatekeeper: Cooldowns & Dead Checks
	if is_switching or not can_switch: return
	if target_index >= characters.size(): return
	
	# NEW: Optimization to prevent switching to self
	if target_index == active_character_index: return
	
	if characters[target_index].is_dead:
		print("Character Dead")
		return
	perform_switch(target_index)

func perform_switch(target_index: int):
	is_switching = true 
	can_switch = false 
	
	var old_char = characters[active_character_index]
	
	# NEW: Audio (Wrapped in has_singleton check just in case, but usually called directly)
	# Assuming you have an Autoload named AudioManager
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("switch", 0.1)
	
	play_vfx(old_char.global_position)
	if old_char.has_node("main_sprite"): old_char.get_node("main_sprite").visible = false
	
	active_character_index = target_index
	var new_char = characters[active_character_index]
	
	# --- UPDATE UI ---
	if echo_deck_ui:
		echo_deck_ui.highlight_card(active_character_index)
		update_ui_button_state(new_char)
	
	# Swap Physics/Logic
	new_char.global_position = old_char.global_position
	deactivate_character(old_char)
	activate_character(new_char)
	
	# NEW: Invulnerability Trigger on Switch
	if new_char.has_method("start_invulnerability"):
		new_char.start_invulnerability() # Removed 'false' arg to match likely existing method signature
	
	# Visuals & Speed
	var duration = 0.5 
	if switch_vfx.sprite_frames.has_animation("switch"):
		var frames = switch_vfx.sprite_frames.get_frame_count("switch")
		var fps = switch_vfx.sprite_frames.get_animation_speed("switch")
		if fps > 0: duration = frames / fps
		
	var original_speed = new_char.speed
	new_char.speed = original_speed * onCharacterSwitchSpeed
	
	if new_char.has_node("main_sprite"):
		new_char.get_node("main_sprite").visible = false
		await get_tree().create_timer(duration * 0.5).timeout
		new_char.get_node("main_sprite").visible = true
	
	new_char.speed = original_speed
	switch_vfx.visible = false
	
	# Queued Heals
	if queued_heal_amount > 0:
		await get_tree().create_timer(0.1).timeout
		if new_char.has_method("receive_heal"): new_char.receive_heal(queued_heal_amount)
		queued_heal_amount = 0
	
	is_switching = false
	await get_tree().create_timer(SWITCH_COOLDOWN).timeout
	can_switch = true

func update_ui_button_state(char_node):
	if echo_deck_ui and char_node.has_method("get_cooldown_status"):
		var status = char_node.get_cooldown_status() 
		echo_deck_ui.update_skill_button(char_node.ability_name, status[0], status[1])

func _on_character_died(_dead_char_node):
	var next_alive_index = -1
	for i in range(1, characters.size()):
		var check_index = (active_character_index + i) % characters.size()
		if not characters[check_index].is_dead:
			next_alive_index = check_index
			break
	
	if next_alive_index != -1:
		print("Switching to next survivor: ", characters[next_alive_index].name)
		perform_switch(next_alive_index)
	else:
		print("GAME OVER")

func play_vfx(pos):
	switch_vfx.global_position = pos
	switch_vfx.visible = true
	switch_vfx.play("switch")
	switch_vfx.frame = 0 

func activate_character(char_node):
	if char_node.is_dead: return
	
	# NEW: Reset Visuals check
	if char_node.has_method("reset_visuals"):
		char_node.reset_visuals()
		
	char_node.visible = true
	if char_node.has_node("main_sprite"): char_node.get_node("main_sprite").visible = true
	char_node.set_process_unhandled_input(true)
	char_node.set_physics_process(true)
	char_node.process_mode = Node.PROCESS_MODE_INHERIT
	if camera: camera.target = char_node

func deactivate_character(char_node):
	# NEW: Reset Visuals check
	if char_node.has_method("reset_visuals"):
		char_node.reset_visuals()

	char_node.visible = false
	char_node.set_process_unhandled_input(false)
	char_node.set_physics_process(false)
	char_node.process_mode = Node.PROCESS_MODE_DISABLED

func queue_heal_for_next_switch(amount: int):
	queued_heal_amount = amount
	print("Heal queued!")
