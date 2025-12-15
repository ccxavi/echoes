extends CanvasLayer

func _ready() -> void:
	visible = false # Hide menu at start

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # "ESC" key
		_toggle_pause_state()

func _toggle_pause_state() -> void:
	visible = not visible
	get_tree().paused = visible

# --- BUTTON FUNCTIONS ---

# 1. RESUME: Just toggle the pause state back to normal
func _on_resume_pressed() -> void:
	_toggle_pause_state()

# 2. RESTART: Unpause first, then reload the current level
func _on_restart_pressed() -> void:
	_toggle_pause_state() # Important: Unpause before reloading!
	get_tree().reload_current_scene()

# 3. QUIT (To Main Menu): Unpause first, then switch scenes
func _on_quit_pressed() -> void:
	_toggle_pause_state() # Important: Unpause before leaving!
	get_tree().change_scene_to_file("res://scenes/mainMenu.tscn")
