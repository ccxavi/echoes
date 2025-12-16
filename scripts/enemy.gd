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
@export var detection_range = 1000.0 
@export var stop_distance = 20.0    
@export var attack_windup_time = 0.8 

# --- STATE VARIABLES ---
var hp = max_hp
var can_attack = true
var knockback_velocity = Vector2.ZERO 

# --- BURN STATE ---
var is_burning: bool = false
var burn_duration: float = 0.0
var burn_damage_per_tick: int = 0
var burn_tick_timer: float = 0.0

# --- NODES ---
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $hitbox
@onready var vfx: AnimatedSprite2D = $vfx
@onready var hit_particles: CPUParticles2D = $HitParticles 
@onready var death: AnimatedSprite2D = $death

func _ready():
	hp = max_hp
	
	if death:
		death.visible = false
	
	# 1. SETUP VFX
	vfx.visible = false 
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
	
	if is_burning:
		_process_burn(delta)

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
		# If we are close enough, stop moving and ATTACK
		if can_attack: 
			start_attack_sequence()
		
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
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, is_critical: bool = false, is_fire_damage: bool = false):
	hp -= amount
	
	# --- 1. ANIMATION & VFX ---
	vfx.visible = true
	vfx.frame = 0
	
	if is_fire_damage:
		# LOGIC: This damage came from the fire tick
		vfx.play("fire") 
		vfx.rotation = randf_range(0, 6.28) 
	else:
		# LOGIC: This damage came from a physical hit (Sword/Arrow)
		# Even if they are burning, we play the slash because a sword just hit them!
		vfx.play("slash") 
		vfx.rotation = 0

	# --- 2. KNOCKBACK ---
	# We ONLY apply knockback if it is NOT fire damage.
	# Physical hits get knockback. Fire ticks do not.
	if source_pos != Vector2.ZERO and not is_fire_damage:
		var knockback_dir = (global_position - source_pos).normalized()
		var power = knockback_power * 1.5 if is_critical else knockback_power
		knockback_velocity = knockback_dir * power
		
		# Rotate particles to face away from the hit
		if hit_particles: 
			hit_particles.rotation = knockback_dir.angle()
			hit_particles.restart()
			hit_particles.emitting = true

	# --- 3. FLASH COLOR ---
	if is_fire_damage:
		modulate = Color(2, 0.5, 0) # Orange Flash
	elif is_critical:
		modulate = Color(3, 0, 0)   # Red Flash
	else:
		modulate = Color(10, 10, 10) # White Flash
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# Debugging
	var source = "Burn" if is_fire_damage else "Attack"
	print("%s took %s damage from %s. HP: %s" % [name, amount, source, hp])

	if hp <= 0:
		die()

func start_attack_sequence():
	can_attack = false
	#play_anim("attack")
	await get_tree().create_timer(attack_windup_time).timeout
	
	var bodies = hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage, global_position)
	
	#await animated_sprite_2d.animation_finished
	#play_anim("idle")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func die():
	# Prevent code from running twice if hit quickly while dying
	if not is_physics_processing():
		return

	# 1. STOP GAMEPLAY LOGIC
	set_physics_process(false) # Stop movement and attacks
	can_attack = false
	velocity = Vector2.ZERO
	
	# 2. HIDE ALIVE VISUALS
	animated_sprite_2d.visible = false 
	vfx.visible = false # Stop showing fire/slashes
	if hit_particles: hit_particles.emitting = false

	# 3. PLAY DEATH ANIMATION
	if death:
		death.visible = true
		death.play("default")
		
		# Wait for it to finish
		await death.animation_finished
	
	# 4. DELETE OBJECT
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
	vfx.visible = false

func apply_burn(dmg_per_tick: int, duration: float):
	is_burning = true
	burn_damage_per_tick = dmg_per_tick
	burn_duration = duration
	burn_tick_timer = 0.0
	
	# Visual feedback: Turn Orange
	modulate = Color(1.5, 0.5, 0)

func _process_burn(delta: float):
	burn_duration -= delta
	burn_tick_timer -= delta
	
	if burn_tick_timer <= 0:
		take_damage(burn_damage_per_tick, Vector2.ZERO, false, true)
		burn_tick_timer = 1.0 
	
	if burn_duration <= 0:
		is_burning = false
		modulate = Color.WHITE
