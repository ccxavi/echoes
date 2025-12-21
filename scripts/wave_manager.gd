class_name WaveManager extends Node

# SIGNALS
signal wave_started(wave_number: int)
signal wave_completed

# CONFIGURATION
@export var spawn_points_container: Node2D # A Node holding Marker2D children
@export var time_between_waves: float = 5.0

# ENEMY POOL (The "Menu" the manager can order from)
# We use a Dictionary to map Scenes to their "Cost"
@export var enemy_scenes: Array[PackedScene]
@export var enemy_costs: Array[int] = [1, 3] # Index 0 costs 1, Index 1 costs 3, etc.
@onready var enemy_container: Node2D = $"../enemies"

# DIFFICULTY SCALING
@export var initial_budget: int = 20
@export var budget_multiplier: float = 2 # Budget grows twice each wave
@export var hp_scaling_per_wave: int = 5    # Enemies get +5 HP per wave
@export var damage_scaling_per_wave: int = 1 # Enemies hit +1 harder per wave

# STATE
var current_wave: int = 0
var enemies_alive: int = 0
var is_spawning: bool = false

func _ready():
	# Start the first wave after a short delay
	await get_tree().create_timer(2.0).timeout
	start_next_wave()

func start_next_wave():
	current_wave += 1
	wave_started.emit(current_wave)
	
	# Calculate Budget (Linear or Exponential growth)
	# Formula: Base + (Wave * Growth)
	var budget = float(initial_budget) * pow(budget_multiplier, current_wave - 1)
	
	print("--- WAVE %s STARTED (Budget: %d) ---" % [current_wave, int(budget)])
	spawn_wave(int(budget))

func spawn_wave(budget: int):
	is_spawning = true
	var spawn_points = spawn_points_container.get_children()
	
	while budget > 0:
		# 1. Pick a random enemy type
		var index = randi() % enemy_scenes.size()
		var cost = enemy_costs[index]
		
		# 2. Can we afford it?
		if cost > budget:
			# If we can't afford a big guy, try to find a cheaper one
			# (Simple fallback: just break loop if budget is tiny)
			if budget < _get_cheapest_cost():
				break
			continue # Try picking again
		
		# 3. Spawn the enemy
		var point = spawn_points.pick_random()
		# Add random offset so they don't stack perfectly on one pixel
		var pos = point.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		
		create_enemy(enemy_scenes[index], pos)
		budget -= cost
		
		# Small delay between spawns so they don't all appear instantly
		await get_tree().create_timer(0.2).timeout
	
	is_spawning = false

func create_enemy(scene: PackedScene, pos: Vector2):
	var enemy = scene.instantiate()
	enemy.global_position = pos
	
	# --- SCALING: BUFF THE ENEMY ---
	# We modify the properties before adding them to the scene
	if "max_hp" in enemy:
		enemy.max_hp += (current_wave * hp_scaling_per_wave)
		enemy.hp = enemy.max_hp # Heal to full
		
	if "damage" in enemy:
		enemy.damage += (current_wave * damage_scaling_per_wave)
	
	# --- TRACKING ---
	# We need to know when they die to end the wave
	# tree_exited is a built-in signal that fires when queue_free() finishes
	enemy.tree_exited.connect(_on_enemy_died)
	
	if enemy_container:
		enemy_container.call_deferred("add_child", enemy)
	else:
		print("Error: Enemy Container not assigned in WaveManager!")
		# Fallback just in case
		get_tree().current_scene.call_deferred("add_child", enemy)
		
	enemies_alive += 1

func _on_enemy_died():
	enemies_alive -= 1
	
	# If everyone is dead AND we finished spawning...
	if enemies_alive <= 0 and not is_spawning:
		print("Wave Cleared!")
		wave_completed.emit()
		
		# Wait for next wave
		await get_tree().create_timer(time_between_waves).timeout
		start_next_wave()

func _get_cheapest_cost() -> int:
	var min_cost = 999
	for c in enemy_costs:
		if c < min_cost: min_cost = c
	return min_cost
