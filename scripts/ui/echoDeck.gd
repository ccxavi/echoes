extends CanvasLayer

# --- SIGNALS ---
signal switch_requested(index)
signal skill_button_pressed
signal stats_requested

# --- REFERENCES ---
@onready var count_label = $MarginContainer2/EnemyCount/InternalPadding/HBoxContainer/Label

@onready var cardContainers = [
	$MarginContainer/VBoxContainer/HBoxContainer1, 
	$MarginContainer/VBoxContainer/HBoxContainer2, 
	$MarginContainer/VBoxContainer/HBoxContainer3,
	$MarginContainer/VBoxContainer/HBoxContainer4
]

@onready var cards = [
	$MarginContainer/VBoxContainer/HBoxContainer1/PanelContainer1, 
	$MarginContainer/VBoxContainer/HBoxContainer2/PanelContainer2, 
	$MarginContainer/VBoxContainer/HBoxContainer3,
	$MarginContainer/VBoxContainer/HBoxContainer4
]

@onready var pause_button = $MainMenu 
@onready var pause_menu_layer = get_node_or_null("../pauseMenu")

var party_manager_ref = null
var wave_manager_ref = null

func _ready():
	# Find Managers
	party_manager_ref = get_tree().current_scene.find_child("party_manager", true, false)
	wave_manager_ref = get_tree().current_scene.find_child("WaveManager", true, false)
	
	# Wait for levels to finish instantiating characters
	await get_tree().process_frame
	refresh_party_ui()

	# CONNECT SIGNALS
	for i in range(cards.size()):
		cards[i].gui_input.connect(_on_card_input.bind(i))
	
	if pause_button: 
		pause_button.pressed.connect(_on_pause_pressed)

	if party_manager_ref:
		party_manager_ref.child_order_changed.connect(refresh_party_ui)

func _process(_delta: float) -> void:
	update_enemy_ui()

# --- ENEMY & WAVE HUD LOGIC ---

func update_enemy_ui():
	if count_label and wave_manager_ref:
		var count = wave_manager_ref.enemies_alive
		var wave = wave_manager_ref.current_wave
		count_label.text = "WAVE %d | ENEMIES: %d" % [wave, count]

# --- PARTY UI LOGIC ---

func get_actual_characters() -> Array:
	var valid_members = []
	if party_manager_ref:
		for child in party_manager_ref.get_children():
			if child is CharacterBody2D and "hp" in child:
				valid_members.append(child)
	return valid_members

func refresh_party_ui():
	var party_members = get_actual_characters()
	for i in range(cards.size()):
		if i < party_members.size():
			cardContainers[i].visible = true
			var member = party_members[i]
			
			# Update Health
			update_character_health(i, member.hp, member.max_hp)
			
			# Update Portrait
			var portrait = cardContainers[i].find_child("Portrait", true, false)
			if portrait and "portrait_img" in member:
				portrait.texture = member.portrait_img
		else:
			cardContainers[i].visible = false

# --- INPUT & LOGIC ---

func _input(event):
	var party_count = get_actual_characters().size()

	# Character Switching
	if event.is_action_pressed("switch_1") and party_count >= 1: emit_signal("switch_requested", 0)
	elif event.is_action_pressed("switch_2") and party_count >= 2: emit_signal("switch_requested", 1)
	elif event.is_action_pressed("switch_3") and party_count >= 3: emit_signal("switch_requested", 2) 
	elif event.is_action_pressed("switch_4") and party_count >= 4: emit_signal("switch_requested", 3)

func _on_pause_pressed():
	if pause_menu_layer:
		pause_menu_layer._toggle_pause_state()

func _on_card_input(event: InputEvent, index: int):
	if index >= get_actual_characters().size(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			emit_signal("switch_requested", index)

func highlight_card(active_index):
	for i in range(cards.size()):
		cards[i].modulate = Color(1, 1, 1, 1) if i == active_index else Color(0.5, 0.5, 0.5, 0.8)

func update_character_health(index: int, current_hp: int, max_hp: int):
	if index < 0 or index >= cards.size(): return
	var h_box = cards[index]
	var progress_bar = h_box.find_child("ProgressBar", true, false)
	if not progress_bar: progress_bar = h_box.find_child("TextureProgressBar", true, false)
	
	if progress_bar:
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		var percent = float(current_hp) / float(max_hp)
		var health_color = Color.GREEN 
		if percent <= 0.25: health_color = Color.RED
		elif percent <= 0.5: health_color = Color.YELLOW
		
		if progress_bar is TextureProgressBar:
			progress_bar.tint_progress = health_color
		else:
			progress_bar.modulate = health_color
