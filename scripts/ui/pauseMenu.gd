extends CanvasLayer

# --- REFERENCES ---
@onready var stats_modal = $StatsModal

# We now reference the PanelContainers so we can hide the entire "slot" background
@onready var stat_slots = [
	$StatsModal/StatsPanel/HBoxContainer/PanelContainer1,
	$StatsModal/StatsPanel/HBoxContainer/PanelContainer2,
	$StatsModal/StatsPanel/HBoxContainer/PanelContainer3,
	$StatsModal/StatsPanel/HBoxContainer/PanelContainer4
]

var party_manager_ref = null

func _ready() -> void:
	visible = false 
	if stats_modal: stats_modal.visible = false
	party_manager_ref = get_tree().current_scene.find_child("party_manager", true, false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause_state()

func _toggle_pause_state() -> void:
	visible = not visible
	get_tree().paused = visible
	
	if visible:
		_refresh_stats_display()
	else:
		stats_modal.visible = false

# --- STATS LOGIC ---

func _get_actual_characters() -> Array:
	var valid_members = []
	if party_manager_ref:
		for child in party_manager_ref.get_children():
			if child is CharacterBody2D and "hp" in child:
				valid_members.append(child)
	return valid_members

func _refresh_stats_display():
	var characters_in_party = _get_actual_characters()
	
	for i in range(stat_slots.size()):
		var slot = stat_slots[i] # This is the PanelContainer
		
		if i < characters_in_party.size():
			# Show the entire box for this character
			slot.visible = true
			var char_node = characters_in_party[i]
			
			# Find labels inside this specific slot
			var name_lbl = slot.find_child("NameLabel", true, false)
			var hp_lbl = slot.find_child("HPLabel", true, false)
			var atk_lbl = slot.find_child("AtkLabel", true, false)
			var def_lbl = slot.find_child("DefLabel", true, false)
			var spd_lbl = slot.find_child("SpdLabel", true, false)
			var crit_lbl = slot.find_child("CritLabel", true, false)
			
			# 1. Identity & Health
			if name_lbl: name_lbl.text = char_node.name.to_upper()
			if hp_lbl: hp_lbl.text = "HP: %d / %d" % [char_node.hp, char_node.max_hp]
			
			# 2. Stats (Warrior, Lancer, Goblin use Damage; Monk uses Heal)
			if atk_lbl:
				if "heal_amount" in char_node and char_node.damage == 0:
					atk_lbl.text = "HEAL: %d" % char_node.heal_amount
				else:
					atk_lbl.text = "ATK: %d" % char_node.damage
					
			if def_lbl: def_lbl.text = "DEF: %d" % char_node.defense
			if spd_lbl: spd_lbl.text = "SPD: %d" % char_node.speed
			
			# 3. Crit formatting (0.5 -> 50%)
			if crit_lbl:
				crit_lbl.text = "CRIT: %d%%" % (char_node.crit_chance * 100)
				
		else:
			# Hide the entire PanelContainer if there is no character for this slot
			slot.visible = false

# --- BUTTONS ---

func _on_close_stats():
	stats_modal.visible = false

func _on_resume_pressed() -> void:
	_toggle_pause_state()

func _on_restart_pressed() -> void:
	_toggle_pause_state() 
	get_tree().reload_current_scene()

func _on_stats_pressed() -> void:
	stats_modal.visible = true
	_refresh_stats_display()
	
func _on_quit_pressed() -> void:
	_toggle_pause_state()
	get_tree().change_scene_to_file("res://scenes/ui/mainMenu.tscn")
