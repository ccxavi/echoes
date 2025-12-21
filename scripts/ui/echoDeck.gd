extends CanvasLayer

# --- SIGNALS ---
signal switch_requested(index)
signal skill_button_pressed
signal stats_requested

# --- REFERENCES ---
# New Wave HUD References
@onready var wave_hud_container = $MarginContainer2
@onready var wave_title_label = $MarginContainer2/VBoxContainer/WaveTitleLabel
@onready var wave_progress_bar = $MarginContainer2/VBoxContainer/WaveProgressBar

# Banner References (Centered Pop-up)
@onready var wave_banner = $WaveBannerContainer
@onready var banner_label = $WaveBannerContainer/WaveBannerPanel/InternalPadding/BannerLabel

@onready var cardContainers = [
	$MarginContainer/VBoxContainer/HBoxContainer1, 
	$MarginContainer/VBoxContainer/HBoxContainer2, 
	$MarginContainer/VBoxContainer/HBoxContainer3,
	$MarginContainer/VBoxContainer/HBoxContainer4
]

@onready var cards = [
	$MarginContainer/VBoxContainer/HBoxContainer1/PanelContainer1, 
	$MarginContainer/VBoxContainer/HBoxContainer2/PanelContainer2, 
	$MarginContainer/VBoxContainer/HBoxContainer3/PanelContainer3,
	$MarginContainer/VBoxContainer/HBoxContainer4/PanelContainer4
]

var start_messages = [
	"BRACE YOURSELVES!",
	"THEY'RE COMING...",
	"SHOW NO MERCY!",
	"PREPARE FOR GLORY!",
	"DEFEND THE ECHO!"
]

var clear_messages = [
	"SURVIVED!",
	"AREA SECURED!",
	"EXTERMINATED!",
	"ABSOLUTE VICTORY!",
	"WELL DONE, HEROES!"
]

@onready var pause_button = $MainMenu 
@onready var pause_menu_layer = get_node_or_null("../pauseMenu")

var party_manager_ref = null
var wave_manager_ref = null
var is_endless_mode: bool = false
var total_enemies_this_wave: int = 0

func _ready():
	# 1. Find Managers
	party_manager_ref = get_tree().current_scene.find_child("party_manager", true, false)
	wave_manager_ref = get_tree().current_scene.find_child("WaveManager", true, false)
	
	# Determine Mode based on WaveManager presence
	is_endless_mode = (wave_manager_ref != null)
	
	# 2. Setup Initial State
	if wave_banner: wave_banner.visible = false
	
	# Show Wave HUD only if in endless mode
	if wave_hud_container:
		wave_hud_container.visible = is_endless_mode
	
	# Wait for levels to finish instantiating characters
	await get_tree().process_frame
	refresh_party_ui()

	# 3. Connect UI Signals
	for i in range(cards.size()):
		cards[i].gui_input.connect(_on_card_input.bind(i))
	
	if pause_button: 
		pause_button.pressed.connect(_on_pause_pressed)

	if party_manager_ref:
		party_manager_ref.child_order_changed.connect(refresh_party_ui)

	# 4. Connect Wave Signals (Only for Endless)
	if is_endless_mode:
		wave_manager_ref.wave_started.connect(_on_wave_started)
		wave_manager_ref.wave_completed.connect(_on_wave_completed)

func _process(_delta: float) -> void:
	if is_endless_mode:
		update_wave_hud()

# --- WAVE HUD LOGIC ---

func update_wave_hud():
	if wave_manager_ref and wave_progress_bar:
		var current_count = wave_manager_ref.enemies_alive
		
		# Track the maximum enemies seen this wave to scale the progress bar correctly
		if current_count > total_enemies_this_wave:
			total_enemies_this_wave = current_count
			wave_progress_bar.max_value = total_enemies_this_wave
		
		wave_progress_bar.value = current_count
		
		# FIX: Force display to WAVE 1 if manager is at 0
		var display_wave = wave_manager_ref.current_wave
		if display_wave <= 0: display_wave = 1
		wave_title_label.text = "WAVE %d" % display_wave

		wave_progress_bar.modulate = Color(1.0, 0.2, 0.2)

# --- WAVE & BANNER LOGIC ---

func _on_wave_started(wave_num: int):
	total_enemies_this_wave = 0 # Reset count for the new wave
	var msg = start_messages.pick_random()
	_play_banner_sequence("WAVE %d" % wave_num, msg, Color.ORANGE_RED)

func _on_wave_completed():
	if wave_manager_ref:
		var msg = clear_messages.pick_random()
		_play_simple_banner(msg, Color.GOLD)
		apply_noise_shake(0.4, 10.0)

# --- SEQUENTIAL ANIMATION (For Start) ---
func _play_banner_sequence(top_text: String, sub_text: String, banner_color: Color):
	if not wave_banner: return
	
	wave_banner.visible = true
	wave_banner.modulate = banner_color
	wave_banner.modulate.a = 0
	wave_banner.scale = Vector2(0.3, 0.3)
	wave_banner.pivot_offset = wave_banner.size / 2
	
	banner_label.text = top_text
	var intro = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(wave_banner, "modulate:a", 1.0, 0.4)
	intro.tween_property(wave_banner, "scale", Vector2(1.0, 1.0), 0.4)
	
	await get_tree().create_timer(1.5).timeout
	
	var punch = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	punch.tween_property(wave_banner, "scale", Vector2(1.2, 1.2), 0.1)
	punch.tween_callback(func(): banner_label.text = sub_text)
	punch.tween_property(wave_banner, "scale", Vector2(1.0, 1.0), 0.1)
	
	await get_tree().create_timer(2.0).timeout
	
	var fade = create_tween()
	fade.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	await fade.finished
	wave_banner.visible = false

# --- SIMPLE ANIMATION (For Completion) ---
func _play_simple_banner(text: String, banner_color: Color):
	if not wave_banner: return
	
	banner_label.text = text
	wave_banner.visible = true
	wave_banner.modulate = banner_color
	wave_banner.modulate.a = 0
	wave_banner.scale = Vector2(0.5, 0.5)
	wave_banner.pivot_offset = wave_banner.size / 2
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave_banner, "modulate:a", 1.0, 0.4)
	tween.tween_property(wave_banner, "scale", Vector2(1.0, 1.0), 0.4)
	
	await get_tree().create_timer(2.0).timeout
	
	var fade = create_tween()
	fade.tween_property(wave_banner, "modulate:a", 0.0, 0.5)
	await fade.finished
	wave_banner.visible = false

func apply_noise_shake(duration: float, intensity: float):
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	var tween = create_tween()
	for i in range(8):
		var shake_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", shake_offset, duration / 8.0)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

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
			update_character_health(i, member.hp, member.max_hp)
			var portrait = cardContainers[i].find_child("Portrait", true, false)
			if portrait and "portrait_img" in member:
				portrait.texture = member.portrait_img
		else:
			cardContainers[i].visible = false

func highlight_card(active_index: int):
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

# --- INPUT ---

func _input(event):
	var party_count = get_actual_characters().size()
	if event.is_action_pressed("switch_1") and party_count >= 1: emit_signal("switch_requested", 0)
	elif event.is_action_pressed("switch_2") and party_count >= 2: emit_signal("switch_requested", 1)
	elif event.is_action_pressed("switch_3") and party_count >= 3: emit_signal("switch_requested", 2) 
	elif event.is_action_pressed("switch_4") and party_count >= 4: emit_signal("switch_requested", 3)
	
func _on_pause_pressed():
	if pause_menu_layer:
		pause_menu_layer._toggle_pause_state()

func _on_card_input(event: InputEvent, index: int):
	if index >= get_actual_characters().size() or not (event is InputEventMouseButton and event.pressed): return
	if event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		emit_signal("switch_requested", index)
