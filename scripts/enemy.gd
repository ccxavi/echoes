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
@export var detection_range = 300.0 
@export var stop_distance = 20.0    
@export var attack_windup_time = 0.5
@export var alert_duration = 0.6 # How long to stand still while "!" plays

# --- STATE VARIABLES ---
var hp = max_hp
var can_attack = true
var knockback_velocity = Vector2.ZERO 
var is_alerted: bool = false 
var is_reacting: bool = false # Blocks AI while the "!" animation plays

# --- AUDIO VARIABLES ---
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.35 

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
	if death: death.visible = false
	
	vfx.visible = false 
	if not vfx.animation_finished.is_connected(_on_vfx_finished):
		vfx.animation_finished.connect(_on_vfx_finished)

	if hitbox and not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	if hit_particles: 
		hit_particles.emitting = false

func _physics_process(delta: float) -> void:
	if footstep_timer > 0:
		footstep_timer -= delta

	# 1. KNOCKBACK PHYSICS (Always takes priority)
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		velocity = knockback_velocity
		move_and_slide()
		return 
	
	if is_burning:
		_process_burn(delta)

	# 2. WAIT FOR ALERT (New Priority Check)
	# If we are currently playing the "!" animation, do nothing else.
	if is_reacting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 3. State Check
	if not can_attack:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# 4. Find Target
	var target = get_active_player()
	
	if target == null:
		if is_alerted: is_alerted = false
		idle_behavior()
		return

	# 5. Calculate Distance
	var dist = global_position.distance_to(target.global_position)

	# 6. Decide Action
	if dist <= stop_distance:
		velocity = Vector2.ZERO
		if can_attack: 
			start_attack_sequence(target)
		else:
			if animated_sprite_2d.animation != "attack":
				play_anim("idle")
		
	elif dist < detection_range:
		# If we haven't seen the player yet...
		if not is_alerted:
			start_alert_sequence(target) # Trigger the pause + VFX
		else:
			# If we already did the alert, just chase normally
			chase_target(target)
	else:
		# Player escaped range
		if is_alerted: is_alerted = false
		idle_behavior()

# --- ALERT SEQUENCE ---
func start_alert_sequence(target: Node2D):
	is_reacting = true  # Locks movement in _physics_process
	velocity = Vector2.ZERO # Stop moving immediately
	
	# Face the player so we look surprised AT them
	var direction = global_position.direction_to(target.global_position)
	face_direction(direction.x)
	play_anim("idle")
	
	play_alert_vfx()
	
	# Wait for the animation/reaction time
	await get_tree().create_timer(alert_duration).timeout
	
	is_alerted = true # Mark as seen
	is_reacting = false # Unlock movement

func play_alert_vfx():
	if vfx:
		vfx.visible = true
		vfx.frame = 0
		vfx.rotation = 0
		vfx.position = Vector2(0, -40) 
		vfx.play("exclamation")
		AudioManager.play_sfx("exclamation", 0.0, -8.0)

# --- MOVEMENT LOGIC ---
func chase_target(target: Node2D):
	var direction = global_position.direction_to(target.global_position)
	var final_velocity = direction * speed
	final_velocity += get_separation_force()
	
	velocity = final_velocity
	move_and_slide()
	
	play_anim("run")
	
	if footstep_timer <= 0:
		AudioManager.play_sfx("grass", 0.1, -20.0)
		footstep_timer = FOOTSTEP_INTERVAL
	
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
	if dir_x < 0: 
		animated_sprite_2d.flip_h = true 
	elif dir_x > 0: 
		animated_sprite_2d.flip_h = false

# --- COMBAT LOGIC ---
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, is_critical: bool = false, is_fire_damage: bool = false):
	hp -= amount
	
	# RESET VFX position in case it was moved by Alert logic
	vfx.visible = true
	vfx.frame = 0
	vfx.position = Vector2.ZERO 
	
	if is_fire_damage:
		vfx.play("fire") 
		vfx.rotation = randf_range(0, 6.28) 
	else:
		vfx.play("slash") 
		vfx.rotation = 0
		
	if source_pos != Vector2.ZERO and not is_fire_damage:
		var knockback_dir = (global_position - source_pos).normalized()
		var power = knockback_power * 1.5 if is_critical else knockback_power
		knockback_velocity = knockback_dir * power
		
		if hit_particles: 
			hit_particles.rotation = knockback_dir.angle()
			hit_particles.restart()
			hit_particles.emitting = true

	if is_fire_damage:
		modulate = Color(2, 0.5, 0)
		AudioManager.play_sfx("fire", 0.1, -20)
	elif is_critical:
		modulate = Color(0.6, 0, 0) 
		AudioManager.play_sfx("crit", 0.1)
	else:
		modulate = Color(10, 10, 10)
		AudioManager.play_sfx("hit", 0.1)
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	var source = "Burn" if is_fire_damage else "Attack"
	print("%s took %s damage from %s. HP: %s" % [name, amount, source, hp])

	if hp <= 0:
		die()

func start_attack_sequence(target_node = null):
	can_attack = false
	
	if target_node:
		var dir_to_target = global_position.direction_to(target_node.global_position)
		face_direction(dir_to_target.x)
	
	play_anim("attack")
	AudioManager.play_sfx("woosh", 0.1, -10)
	
	if hp > 0:
		var bodies = hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage, global_position, self)
	
	await get_tree().create_timer(attack_windup_time).timeout
	
	if animated_sprite_2d.animation == "attack" and animated_sprite_2d.is_playing():
		await animated_sprite_2d.animation_finished
	
	play_anim("idle")
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func die():
	if not is_physics_processing(): return

	set_physics_process(false)
	can_attack = false
	velocity = Vector2.ZERO
	
	animated_sprite_2d.visible = false 
	vfx.visible = false
	if hit_particles: hit_particles.emitting = false

	if death:
		death.visible = true
		death.play("default")
		AudioManager.play_sfx("enemy_death", 0.1)
		await death.animation_finished
	
	queue_free()

func get_active_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if p.visible: return p
	return null

func play_anim(anim_name: String):
	if animated_sprite_2d.animation == anim_name and animated_sprite_2d.is_playing():
		return
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _on_hitbox_body_entered(_body): pass
func _on_vfx_finished(): vfx.visible = false

func apply_burn(dmg_per_tick: int, duration: float):
	is_burning = true
	burn_damage_per_tick = dmg_per_tick
	burn_duration = duration
	burn_tick_timer = 0.0
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
