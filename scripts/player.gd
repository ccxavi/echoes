class_name Character extends CharacterBody2D

@export var speed = 300.0
@export var damage = 1 # Add damage var so classes can change it

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

# --- CORE ATTACK LOGIC (Shared by everyone) ---
func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO 
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	# 1. ROTATE HITBOX (Always faces mouse 360 degrees)
	weapon_pivot.look_at(mouse_pos)
	
	# 2. PLAY ANIMATION (Overridable!)
	# We pass the mouse direction vector so the child class can decide the sprite
	play_attack_animation(diff)

	# 3. DELAY FOR IMPACT
	await get_tree().create_timer(0.2).timeout
	
	# 4. DETECT ENEMIES
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy"):
			# Pass damage and position for knockback
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position)

# --- VIRTUAL FUNCTION (Standard 4-Way Logic) ---
# The Lancer will replace this function with its own version
func play_attack_animation(diff: Vector2):
	if abs(diff.y) > abs(diff.x):
		if diff.y < 0: 
			play_anim("attack_up")
		else: 
			play_anim("attack_down")
	else:
		play_anim("attack_side")
		# Flip only for side attacks in the base class
		animated_sprite_2d.flip_h = (diff.x < 0)

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _on_animation_finished():
	# Smart check: If any animation starting with "attack" finishes, unlock movement
	if animated_sprite_2d.animation.begins_with("attack"):
		is_attacking = false
