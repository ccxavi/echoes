extends Control

# --- REFERENCES ---
# Ensure 'leaderboard' is the name of your instantiated scene in the editor
@onready var leaderboard_ui = $Leaderboard 
@onready var lb_button = $Menu/VBoxContainer/Leaderboard

func _ready() -> void:
	AudioManager.play_music("menu_theme", -10.0, true)
	# 1. Hide leaderboard by default
	if leaderboard_ui:
		leaderboard_ui.visible = false

# --- BUTTON HANDLERS ---

func _on_play_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/level_selection.tscn")

func _on_leaderboard_pressed() -> void:
	AudioManager.play_sfx("click")
	if leaderboard_ui:
		leaderboard_ui.visible = true # This makes the leaderboard appear again


func _on_quit_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().quit()
