extends CanvasLayer

# --- SIGNALS ---
signal switch_requested(index)
signal skill_button_pressed 
signal stats_requested 

# --- REFERENCES ---
@onready var cards = [
	$MarginContainer/VBoxContainer/HBoxContainer1, 
	$MarginContainer/VBoxContainer/HBoxContainer2, 
	$MarginContainer/VBoxContainer/HBoxContainer3, 
	$MarginContainer/VBoxContainer/HBoxContainer4
]

@onready var pause_button = $MainMenu 
@onready var pause_menu_layer = get_node_or_null("../pauseMenu")

# --- STATS MODAL REFERENCES ---
@onready var stats_modal = $StatsModal
@onready var stats_tab_btn = $Tab
@onready var stats_exit_btn = $StatsModal/StatsPanel/Exit 

@onready var stat_columns = [
	$StatsModal/StatsPanel/HBoxContainer/Column1,
	$StatsModal/StatsPanel/HBoxContainer/Column2,
	$StatsModal/StatsPanel/HBoxContainer/Column3,
	$StatsModal/StatsPanel/HBoxContainer/Column4
]

var party_manager_ref = null

func _ready():
	if stats_modal: stats_modal.visible = false

	# FIND PARTY_MANAGER
	party_manager_ref = get_tree().current_scene.find_child("party_manager", true, false)
	
	# Wait for levels to finish instantiating characters
	await get_tree().process_frame
	refresh_party_ui()

	# CONNECT SIGNALS
	for i in range(cards.size()):
		cards[i].gui_input.connect(_on_card_input.bind(i))
	
	if pause_button: pause_button.pressed.connect(_on_pause_pressed)
	if stats_tab_btn: stats_tab_btn.pressed.connect(_on_request_stats)
	if stats_exit_btn: stats_exit_btn.pressed.connect(_on_close_stats)

	if party_manager_ref:
		party_manager_ref.child_order_changed.connect(refresh_party_ui)

# --- THE FILTER: This finds only nodes of Character type ---
func get_actual_characters() -> Array:
	var valid_members = []
	if party_manager_ref:
		for child in party_manager_ref.get_children():
			# Filter: Is it a CharacterBody2D and does it have HP?
			if child is CharacterBody2D and "hp" in child:
				valid_members.append(child)
	return valid_members

func refresh_party_ui():
	var party_members = get_actual_characters()
	var party_count = party_members.size()

	for i in range(cards.size()):
		if i < party_count:
			# If character exists (e.g. 0 is always Warrior), show the UI row
			cards[i].visible = true
			stat_columns[i].visible = true
			
			var member = party_members[i]
			
			# Update Health
			if "hp" in member and "max_hp" in member:
				update_character_health(i, member.hp, member.max_hp)
			
			# Update Portrait
			var portrait = cards[i].find_child("Portrait", true, false)
			if portrait and "portrait_img" in member:
				portrait.texture = member.portrait_img
		else:
			# If character doesn't exist (e.g. Monk in Village), hide the UI row
			cards[i].visible = false
			stat_columns[i].visible = false

# --- INPUT & LOGIC ---

func _input(event):
	var party_count = get_actual_characters().size()

	# Use the character count to prevent switching to empty slots
	if event.is_action_pressed("switch_1") and party_count >= 1: emit_signal("switch_requested", 0)
	elif event.is_action_pressed("switch_2") and party_count >= 2: emit_signal("switch_requested", 1)
	elif event.is_action_pressed("switch_3") and party_count >= 3: emit_signal("switch_requested", 2) 
	elif event.is_action_pressed("switch_4") and party_count >= 4: emit_signal("switch_requested", 3)
	
	if event.is_action_pressed("show_stats"):
		_on_request_stats() 
	elif event.is_action_released("show_stats"):
		_on_close_stats()    

func _on_pause_pressed():
	if pause_menu_layer:
		pause_menu_layer.visible = true
		get_tree().paused = true

func _on_request_stats():
	show_stats_screen(get_actual_characters())
	emit_signal("stats_requested")

func _on_close_stats():
	stats_modal.visible = false

func show_stats_screen(characters_data: Array):
	stats_modal.visible = true
	for i in range(stat_columns.size()):
		var column = stat_columns[i]
		if i < characters_data.size():
			column.visible = true
			var char_node = characters_data[i]
			var name_lbl = column.find_child("NameLabel", true, false)
			var hp_lbl = column.find_child("HPLabel", true, false)
			var portrait = column.find_child("Portrait", true, false)
			
			if name_lbl: name_lbl.text = char_node.name
			if hp_lbl and "hp" in char_node: hp_lbl.text = "HP: %s/%s" % [char_node.hp, char_node.max_hp]
			if portrait and "portrait_img" in char_node: portrait.texture = char_node.portrait_img
		else:
			column.visible = false

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
