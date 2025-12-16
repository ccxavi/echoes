extends CanvasLayer

# --- SIGNALS ---
signal switch_requested(index)
signal skill_button_pressed 
signal stats_requested 

# --- REFERENCES ---
@onready var cards = [
	$MarginContainer/VBoxContainer/HBoxContainer1/PanelContainer1, 
	$MarginContainer/VBoxContainer/HBoxContainer2/PanelContainer2, 
	$MarginContainer/VBoxContainer/HBoxContainer3/PanelContainer3, 
	$MarginContainer/VBoxContainer/HBoxContainer4/PanelContainer4
]

@onready var skill_button = $AbilityContainer/SkillButton
@onready var cooldown_overlay = $AbilityContainer/SkillButton/CooldownOverlay
@onready var pause_button = $MainMenu/Pause 
@onready var pause_menu_layer = get_node("../pauseMenu")

# --- STATS MODAL REFERENCES ---
@onready var stats_modal = $StatsModal
@onready var stats_tab_btn = $Tab/Stats 
@onready var stats_exit_btn = $StatsModal/StatsPanel/Exit 

@onready var stat_columns = [
	$StatsModal/StatsPanel/HBoxContainer/Column1,
	$StatsModal/StatsPanel/HBoxContainer/Column2,
	$StatsModal/StatsPanel/HBoxContainer/Column3,
	$StatsModal/StatsPanel/HBoxContainer/Column4
]

func _ready():
	# 1. FORCE HIDDEN STATES
	if stats_modal: stats_modal.visible = false
	
	if skill_button:
		skill_button.visible = false 
		skill_button.disabled = true

	# 2. CONNECT SIGNALS
	for i in range(cards.size()):
		cards[i].gui_input.connect(_on_card_input.bind(i))
	
	if skill_button: skill_button.pressed.connect(_on_skill_button_pressed)
	if pause_button: pause_button.pressed.connect(_on_pause_pressed)
	if stats_tab_btn: stats_tab_btn.pressed.connect(_on_request_stats)
	if stats_exit_btn: stats_exit_btn.pressed.connect(_on_close_stats)

	set_process(true)

func _process(delta):
	if cooldown_overlay and cooldown_overlay.value > 0:
		cooldown_overlay.value -= delta
		skill_button.disabled = true
	elif skill_button.visible:
		skill_button.disabled = false

func _input(event):
	# 1. Switching
	if event.is_action_pressed("switch_1"): emit_signal("switch_requested", 0)
	elif event.is_action_pressed("switch_2"): emit_signal("switch_requested", 1)
	elif event.is_action_pressed("switch_3"): emit_signal("switch_requested", 2) 
	elif event.is_action_pressed("switch_4"): emit_signal("switch_requested", 3)
	
	# 2. Stats (Tab)
	if event.is_action_pressed("show_stats"):
		_on_request_stats() 
	elif event.is_action_released("show_stats"):
		_on_close_stats()   

# --- PAUSE LOGIC ---
func _on_pause_pressed():
	if pause_menu_layer:
		pause_menu_layer.visible = true
		get_tree().paused = true

# --- STATS LOGIC ---
func _on_request_stats():
	emit_signal("stats_requested")

func _on_close_stats():
	stats_modal.visible = false

func show_stats_screen(characters_data: Array):
	stats_modal.visible = true
	
	for i in range(stat_columns.size()):
		if i >= characters_data.size(): break
		
		var column = stat_columns[i]
		var char_node = characters_data[i]
		
		var name_lbl = column.find_child("NameLabel", true, false)
		var hp_lbl = column.find_child("HPLabel", true, false)
		var atk_lbl = column.find_child("AtkLabel", true, false)
		var spd_lbl = column.find_child("SpeedLabel", true, false)
		var portrait = column.find_child("Portrait", true, false)
		
		if name_lbl: name_lbl.text = char_node.name
		if hp_lbl and "hp" in char_node: hp_lbl.text = "HP: %s/%s" % [char_node.hp, char_node.max_hp]
		if atk_lbl and "damage" in char_node: atk_lbl.text = "DMG: %s" % char_node.damage
		if spd_lbl and "speed" in char_node: spd_lbl.text = "SPD: %s" % char_node.speed
		if portrait and "portrait_img" in char_node: portrait.texture = char_node.portrait_img

# --- UI UPDATES ---
func _on_card_input(event: InputEvent, index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# --- THE FIX IS HERE ---
			# This tells Godot: "The UI ate this click. Don't send it to the Player."
			get_viewport().set_input_as_handled()
			
			emit_signal("switch_requested", index)

func _on_skill_button_pressed():
	# Mark this handled too, just in case
	get_viewport().set_input_as_handled()
	emit_signal("skill_button_pressed")

func highlight_card(active_index):
	for i in range(cards.size()):
		cards[i].modulate = Color(1, 1, 1, 1) if i == active_index else Color(0.5, 0.5, 0.5, 0.8)

func update_character_health(index: int, current_hp: int, max_hp: int):
	if index < 0 or index >= cards.size(): return
	var card = cards[index]
	var progress_bar = card.find_child("ProgressBar", true, false)
	if not progress_bar: progress_bar = card.find_child("TextureProgressBar", true, false)
	
	if progress_bar:
		# 1. Update Values
		progress_bar.min_value = 0
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		
		# 2. Calculate Percentage
		# We convert to float to get a decimal (e.g., 0.5 for 50%)
		var percent = float(current_hp) / float(max_hp)
		
		# 3. Determine Color
		var health_color = Color.GREEN # Default (Healthy)
		
		if percent <= 0.25:
			health_color = Color.RED    # Critical (< 25%)
		elif percent <= 0.5:
			health_color = Color.YELLOW # Injured (< 50%)
			
		# 4. Apply Color
		if progress_bar is TextureProgressBar:
			# For TextureProgressBar, we tint ONLY the fill bar
			progress_bar.tint_progress = health_color
		else:
			# For standard ProgressBar, we tint the whole node (easiest method)
			progress_bar.modulate = health_color

func update_skill_button(ability_name: String, time_left: float, max_duration: float):
	if not skill_button or not cooldown_overlay: return
	
	if ability_name == "None" or ability_name == "":
		skill_button.visible = false 
		skill_button.disabled = true
		return 

	skill_button.visible = true
	
	if ability_name == "Dash": skill_button.modulate = Color(0.2, 1, 0.2)
	elif ability_name == "Heal": skill_button.modulate = Color(0.2, 0.8, 1)
	else: skill_button.modulate = Color.WHITE

	cooldown_overlay.max_value = max_duration
	cooldown_overlay.value = time_left
	skill_button.disabled = (time_left > 0)

func trigger_cooldown_animation(duration: float):
	if cooldown_overlay:
		cooldown_overlay.max_value = duration
		cooldown_overlay.value = duration
		skill_button.disabled = true
