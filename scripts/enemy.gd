class_name Enemy extends CharacterBody2D

# --- CONFIGURATION ---
@export_group("Movement")
@export var speed = 100.0            
@export var separation_force = 50.0 

@export_group("Combat")
@export var max_hp = 30
@export var damage = 10
@export var attack_cooldown = 1.0
@export var knockback_friction = 600.0
@export var knockback_power = 400.0   

@export_group("AI")
@export var detection_range = 200.0 
@export var stop_distance = 20.0    
@export var attack_windup_time = 0.8 

# --- STATE VARIABLES ---
var hp = max_hp
var can_attack = true
var knockback_velocity = Vector2.ZERO 

# --- NODES ---
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $hitbox
@onready var vfx: AnimatedSprite2D = $vfx
# NEW: Reference the particles
@onready var hit_particles: CPUParticles2D = $HitParticles 

func _ready():
	hp = max_hp
	
	# 1. SETUP VFX
	vfx.visible = false # Start hidden
	# Connect the signal so we know when the slash is done
	if not vfx.animation_finished.is_connected(_on_vfx_finished):
		vfx.animation_finished.connect(_on_vfx_finished)

	# 2. SETUP HITBOX
	if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# 3. SETUP PARTICLES
	if hit_particles: 
		hit_particles.emitting = false

func _physics_process(delta: float) -> void:
	# 1. KNOCKBACK PHYSICS
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity = knockback_velocity
		move_and_slide()
		return 

	# 2. State Check
	if not can_attack:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 3. Find Target
	var target = get_active_player()
	
	if target == null:
		idle_behavior()
		return

	# 4. Calculate Distance
	var dist = global_position.distance_to(target.global_position)

	# 5. Decide Action
	if dist <= stop_distance:
		velocity = Vector2.ZERO
		play_anim("idle")
		# start_attack_sequence() 
		
	elif dist < detection_range:
		chase_target(target)
	else:
		idle_behavior()

# --- MOVEMENT LOGIC ---
func chase_target(target: Node2D):
	var direction = global_position.direction_to(target.global_position)
	var final_velocity = direction * speed
	final_velocity += get_separation_force()
	
	velocity = final_velocity
	move_and_slide()
	
	play_anim("run")
	face_direction(direction.x)

func idle_behavior():
	velocity = Vector2.ZERO
	move_and_slide()
	play_anim("idle")

func get_separation_force() -> Vector2:
	var force = Vector2.ZERO
	var neighbors = get_tree().get_nodes_in_group("enemy")
	for neighbor in neighbors:
		if neighbor != self and global_position.distance_to(neighbor.global_position) < 30:
			var push_dir = (global_position - neighbor.global_position).normalized()
			force += push_dir * separation_force
	return force

func face_direction(dir_x: float):
	if dir_x < 0: animated_sprite_2d.flip_h = true
	elif dir_x > 0: animated_sprite_2d.flip_h = false

# --- COMBAT LOGIC ---
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO):
	hp -= amount
	print(name + " Hit! HP: " + str(hp))
	
	# --- VFX LOGIC ---
	vfx.visible = true
	vfx.frame = 0 # Force restart from beginning
	vfx.play("slash")
	
	# --- EXISTING KNOCKBACK LOGIC ---
	if source_pos != Vector2.ZERO:
		var knockback_dir = (global_position - source_pos).normalized()
		knockback_velocity = knockback_dir * knockback_power
		
		# Removed particle rotation to keep dust static
		if hit_particles: hit_particles.rotation = knockback_dir.angle()

	# --- PAIN ANIMATION ---
	modulate = Color(10, 10, 10) 
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# --- PARTICLES ---
	if hit_particles:
		hit_particles.restart() 
		hit_particles.emitting = true
	
	if hp <= 0:
		die()

func start_attack_sequence():
	can_attack = false
	play_anim("attack")
	await get_tree().create_timer(attack_windup_time).timeout
	
	var bodies = hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
	
	await animated_sprite_2d.animation_finished
	play_anim("idle")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func die():
	queue_free()

# --- HELPERS ---
func get_active_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.visible: return p
	return null

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _on_hitbox_body_entered(_body):
	pass

func _on_vfx_finished():
	# Hide the sprite immediately when animation ends
	vfx.visible = false
