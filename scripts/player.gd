class_name Character extends CharacterBody2D

@export_group("Stats")
@export var speed = 300.0
@export var damage = 1 # temp
@export var crit_chance = 0.2      # 20% Chance
@export var crit_multiplier = 2.0  # Double damage on crit

@onready var animated_sprite_2d: AnimatedSprite2D = $main_sprite
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var attack_area: Area2D = $WeaponPivot/AttackArea

var is_attacking = false

func _ready():
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	if is_attacking:
		return 

	# --- MOVEMENT ---
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	# --- FACING ---
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true 
	else:
		animated_sprite_2d.flip_h = false 

	# --- ANIMATION ---
	if direction != Vector2.ZERO:
		play_anim("run")
	else:
		play_anim("idle")
		
	# --- ATTACK ---
	if Input.is_action_just_pressed("attack"): 
		start_attack()

	move_and_slide()

# --- CORE ATTACK LOGIC ---
func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO 
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	# 1. ROTATE HITBOX
	weapon_pivot.look_at(mouse_pos)
	
	# 2. PLAY ANIMATION
	play_attack_animation(diff)

	# 3. DELAY FOR IMPACT
	await get_tree().create_timer(0.2).timeout
	
	# 4. DETECT ENEMIES & CALCULATE CRIT
	var bodies = attack_area.get_overlapping_bodies()
	
	# A. Calculate Stats
	var is_critical = randf() <= crit_chance
	var final_damage = damage
	
	if is_critical:
		final_damage *= crit_multiplier
	
	# B. Deal Damage & COUNT HITS
	var hit_count = 0 # Changed from boolean to integer
	
	for body in bodies:
		if body.is_in_group("enemy"):
			if body.has_method("take_damage"):
				body.take_damage(final_damage, global_position, is_critical)
				hit_count += 1
	
	# C. Apply Freeze Frame Logic
	if is_critical and hit_count > 0:
		# PRIORITY 1: Critical Hit (Heaviest Freeze)
		print("CRITICAL HIT! Heavy Freeze.")
		freeze_frame(0.05, 0.15) # 0.15 seconds
		
	elif hit_count > 1:
		# PRIORITY 2: Multi-Hit Cleave (Lighter Freeze)
		print("Multi-Hit! Light Freeze.")
		freeze_frame(0.1, 0.1) # 0.1 seconds

func freeze_frame(time_scale: float, duration: float):
	# 1. Slow down the engine
	Engine.time_scale = time_scale
	
	# 2. Wait for 'duration' seconds (ignoring the time scale so it doesn't take forever)
	await get_tree().create_timer(duration, true, false, true).timeout
	
	# 3. Reset speed
	Engine.time_scale = 1.0

func play_attack_animation(diff: Vector2):
	if abs(diff.y) > abs(diff.x):
		if diff.y < 0: 
			play_anim("attack_up")
		else: 
			play_anim("attack_down")
	else:
		play_anim("attack_side")
		animated_sprite_2d.flip_h = (diff.x < 0)

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _on_animation_finished():
	if animated_sprite_2d.animation.begins_with("attack"):
		is_attacking = false
