extends CanvasLayer

@onready var restart: Button = $NinePatchRect/VBoxContainer/Restart
@onready var exit: Button = $NinePatchRect/VBoxContainer/Exit

# Drag your Main Menu scene here in the Inspector
@export var main_menu_path: String = "res://scenes/ui/mainMenu.tscn"

func _ready() -> void:
	# CRITICAL: Allows this UI to work while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect the buttons
	restart.pressed.connect(_on_restart_pressed)
	exit.pressed.connect(_on_exit_pressed)
	
	# Optional: Show cursor if it was hidden
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_restart_pressed() -> void:
	# 1. Reset Game State
	get_tree().paused = false
	Engine.time_scale = 1.0
	
	# 2. Add sound feedback
	if AudioManager: AudioManager.play_sfx("click")
	
	# 3. Reload the Level
	get_tree().reload_current_scene()

func _on_exit_pressed() -> void:
	# 1. Reset Game State
	get_tree().paused = false
	Engine.time_scale = 1.0
	
	if AudioManager: AudioManager.play_sfx("click")
	
	# 2. Go to Main Menu
	get_tree().change_scene_to_file(main_menu_path)
