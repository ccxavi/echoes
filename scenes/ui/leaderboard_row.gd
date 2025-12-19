extends PanelContainer

@onready var rank_lbl = $HBoxContainer/Rank
@onready var name_lbl = $HBoxContainer/PlayerName
@onready var title_lbl = $HBoxContainer/TitleContainer/TitleLabel
@onready var title_panel = $HBoxContainer/TitleContainer
@onready var points_lbl = $HBoxContainer/Points

# Call this function from your main leaderboard script to set the data
func setup(rank: int, player_name: String, title_text: String, score: int):
	rank_lbl.text = "#" + str(rank)
	name_lbl.text = player_name
	title_lbl.text = title_text
	points_lbl.text = str(score).replace(",", "") # Formats points if needed
	
	# Optional: Change Title pill color based on rank type
	_update_title_style(title_text)

func _update_title_style(title: String):
	var style = title_panel.get_theme_stylebox("panel").duplicate()
	match title:
		"Grandmaster": 
			style.bg_color = Color("#2980b9") # Blue
		"Master": 
			style.bg_color = Color("#8e44ad") # Purple
		"Diamond": 
			style.bg_color = Color("#3498db") # Bright Blue
		"Platinum": 
			style.bg_color = Color("#607d8b") # Steel/Grey Blue
		"Gold": 
			style.bg_color = Color("#f1c40f") # Yellow
			
	title_panel.add_theme_stylebox_override("panel", style)
