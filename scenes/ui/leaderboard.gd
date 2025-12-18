extends CanvasLayer

@export var main_menu_path: String = "res://scenes/ui/mainMenu.tscn"

# 1. Path to the PlayerList where rows will be added
@onready var player_list = $MarginContainer/MainPanel/VBoxContainer/ScrollContainer/PlayerList
@onready var back_button = $BackButton
# 2. Preload the row scene you created
const ROW_SCENE = preload("res://scenes/ui/LeaderboardRow.tscn")

func _ready():
	
	var test_players = [
		{"name": "Warrior", "title": "Grandmaster", "points": 2500},
		{"name": "Monk", "title": "Master", "points": 2350},
		{"name": "Lancer", "title": "Diamond", "points": 2100},
		{"name": "Goblin", "title": "Platinum", "points": 1800}
	]
	# Run the test
	populate_leaderboard(test_players)

func populate_leaderboard(data: Array):
	# Clear any placeholder nodes you left in the editor
	for child in player_list.get_children():
		child.queue_free()
	
	# Instantiate rows dynamically
	for i in range(data.size()):
		var player = data[i]
		var row_instance = ROW_SCENE.instantiate()
		
		# Add the row to the VBoxContainer
		player_list.add_child(row_instance)
		
		# Call the setup function we built in LeaderboardRow.gd
		# Rank is i + 1 because arrays start at 0
		if row_instance.has_method("setup"):
			row_instance.setup(i + 1, player.name, player.title, player.points)
			
func _on_back_button_pressed():
	AudioManager.play_sfx("click")
	get_tree().change_scene_to_file(main_menu_path)
