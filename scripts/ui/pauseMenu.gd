extends CanvasLayer

# --- REFERENCES ---
@onready var stats_modal = $StatsModal
@onready var stats_exit_btn = $StatsModal/StatsPanel/Exit 

@onready var stat_columns = [
	$StatsModal/StatsPanel/HBoxContainer/Column1,
	$StatsModal/StatsPanel/HBoxContainer/Column2,
	$StatsModal/StatsPanel/HBoxContainer/Column3,
	$StatsModal/StatsPanel/HBoxContainer/Column4
]

var party_manager_ref = null

func _ready() -> void:
	visible = false # Hide menu at start
	if stats_modal: stats_modal.visible = false
	
	# Find Party Manager in the current scene
	party_manager_ref = get_tree().current_scene.find_child("party_manager", true, false)
	
	# Connect the Stats Exit button
	if stats_exit_btn: 
		stats_exit_btn.pressed.connect(_on_close_stats)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # "ESC" key
		_toggle_pause_state()

func _toggle_pause_state() -> void:
	visible = not visible
	get_tree().paused = visible
	
	if visible:
		# Auto-open stats or just refresh data when menu opens
		_refresh_stats_display()
	else:
		# Ensure stats modal is hidden when the whole menu closes
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
	var characters_data = _get_actual_characters()
	for i in range(stat_columns.size()):
		var column = stat_columns[i]
		if i < characters_data.size():
			column.visible = true
			var char_node = characters_data[i]
			
			var name_lbl = column.find_child("NameLabel", true, false)
			var hp_lbl = column.find_child("HPLabel", true, false)
			var portrait = column.find_child("Portrait", true, false)
			
			if name_lbl: name_lbl.text = char_node.name
			if hp_lbl and "hp" in char_node: 
				hp_lbl.text = "HP: %s/%s" % [char_node.hp, char_node.max_hp]
			if portrait and "portrait_img" in char_node: 
				portrait.texture = char_node.portrait_img
		else:
			column.visible = false

func _on_close_stats():
	stats_modal.visible = false

# --- BUTTON FUNCTIONS ---

func _on_resume_pressed() -> void:
	_toggle_pause_state()

func _on_restart_pressed() -> void:
	_toggle_pause_state() # Unpause before reload
	get_tree().reload_current_scene()

func _on_stats_pressed() -> void:
	# 1. Show the modal
	stats_modal.visible = true
	
	# 2. Update all the labels and portraits with the latest party data
	_refresh_stats_display()
	
func _on_quit_pressed() -> void:
	_toggle_pause_state() # Unpause before scene change
	get_tree().change_scene_to_file("res://scenes/ui/mainMenu.tscn")
