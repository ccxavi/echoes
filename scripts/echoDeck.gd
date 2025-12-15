extends CanvasLayer

signal switch_requested(character_index)

# Match this to your Game Level SWITCH_COOLDOWN (2.0 seconds)
const COOLDOWN_DURATION = 2.0 

@onready var cards = [
	$MarginContainer/VBoxContainer/PanelContainer1, 
	$MarginContainer/VBoxContainer/PanelContainer2, 
	$MarginContainer/VBoxContainer/PanelContainer3, 
	$MarginContainer/VBoxContainer/PanelContainer4
]

# --- NEW VARIABLE ---
var is_on_cooldown = false

func _ready():
	# Since it never hides, we just highlight the first character at start
	update_ui_highlight(0)

func _input(event):
	# If cooldown is active, we ignore input
	if is_on_cooldown:
		return

	# Check for keys 1-4
	if event.is_action_pressed("switch_1"):
		activate_deck(0, "Warrior")
	elif event.is_action_pressed("switch_2"):
		activate_deck(1, "Monk")
	elif event.is_action_pressed("switch_3"):
		# IMPORTANT: Make sure your game node is named "Lancer" exactly!
		activate_deck(2, "Lancer") 
	elif event.is_action_pressed("switch_4"):
		activate_deck(3, "Goblin")

func activate_deck(index, char_name):
	# 1. Update Visuals
	update_ui_highlight(index)
	
	# 2. Send Signal
	emit_signal("switch_requested", char_name)
	
	# 3. Start the Cooldown Lock
	start_cooldown_lock()

func start_cooldown_lock():
	is_on_cooldown = true
	# Wait for 2 seconds
	await get_tree().create_timer(COOLDOWN_DURATION).timeout
	is_on_cooldown = false

func update_ui_highlight(active_index):
	for i in range(cards.size()):
		if i == active_index:
			# Active: Full Brightness
			cards[i].modulate = Color(1, 1, 1, 1)
		else:
			# Inactive: Dimmed
			cards[i].modulate = Color(0.5, 0.5, 0.5, 0.8)
