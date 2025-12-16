extends Control

func _ready() -> void:
	AudioManager.play_music("menu_theme") 

func _process(_delta: float) -> void:
	pass

func _on_play_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file("res://scenes/ui/level_selection.tscn")
	
func _on_quit_pressed() -> void:
	AudioManager.play_sfx("click")
	get_tree().quit()
	
