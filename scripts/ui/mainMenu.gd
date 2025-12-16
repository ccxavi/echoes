extends Control

func _ready() -> void:
	pass 

func _process(_delta: float) -> void:
	pass

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_selection.tscn")
	
func _on_quit_pressed() -> void:
	get_tree().quit()
	
