class_name Character extends CharacterBody2D

@export var speed = 300.0
@onready var animated_sprite_2d: AnimatedSprite2D = $main_sprite

# NEW: Reference the Attack Area
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var attack_area: Area2D = $WeaponPivot/AttackArea

var is_attacking = false

func _ready():
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	if is_attacking:
		return 

	# --- MOVEMENT & FACING ---
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	var mouse_pos = get_global_mouse_position()
	
	# Flip sprite based on mouse
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true 
	else:
		animated_sprite_2d.flip_h = false 

	# Animation
	if direction != Vector2.ZERO:
		play_anim("run")
	else:
		play_anim("idle")
		
	# Attack Input
	if Input.is_action_just_pressed("attack"): 
		start_attack()

	move_and_slide()

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO 
	
	var mouse_pos = get_global_mouse_position()
	var diff = mouse_pos - global_position
	
	# --- 1. ROTATE HITBOX ---
	# We point the pivot at the mouse so the hitbox faces the right way
	weapon_pivot.look_at(mouse_pos)
	
	# --- 2. PLAY ANIMATION ---
	if abs(diff.y) > abs(diff.x):
		if diff.y < 0: play_anim("attack_up")
		else: play_anim("attack_down")
	else:
		play_anim("attack_side")
		animated_sprite_2d.flip_h = (diff.x < 0)

	# --- 3. DELAY FOR IMPACT ---
	# Wait 0.2 seconds (or however long until your sword swings down)
	await get_tree().create_timer(0.2).timeout
	
	# --- 4. DETECT ENEMIES ---
	# Get everything currently inside the AttackArea
	var bodies = attack_area.get_overlapping_bodies()
	
	for body in bodies:
		if body.is_in_group("enemy"):
			body.take_damage(1, global_position)

func _on_animation_finished():
	if animated_sprite_2d.animation in ["attack_side", "attack_up", "attack_down"]:
		is_attacking = false
