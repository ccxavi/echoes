class_name Character extends CharacterBody2D

@export_group("Stats")
@export var max_hp = 100
@export var speed = 300.0
@export var damage = 1 
@export var defense = 0
@export var crit_chance = 0.2
@export var crit_multiplier = 2.0
@export var recoil_strength = 300.0

@export_group("Combat Response")
@export var knockback_strength = 600.0 # How hard we get pushed
@export var knockback_decay = 2000.0   # How fast we stop sliding
@export var invulnerability_time = 1.0 # How long we are safe after hit
@onready var hp = max_hp

@onready var animated_sprite_2d: AnimatedSprite2D = $main_sprite
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var attack_area: Area2D = $WeaponPivot/AttackArea
@onready var vfx: AnimatedSprite2D = $vfx
@onready var particles: CPUParticles2D = $particles
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var collision_shape_2d_attack: CollisionShape2D = $WeaponPivot/AttackArea/CollisionShape2D

var knockback_velocity = Vector2.ZERO
var is_invulnerable = false
var is_attacking = false

const SLIDE_THRESHOLD = 50.0

signal character_died(character_node) # Tells the manager we died
var is_dead = false

func _ready():
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	
	if vfx:
		vfx.visible = false
		vfx.animation_finished.connect(_on_vfx_finished)
	
	if particles:
		particles.emitting = false

func _on_vfx_finished():
	vfx.visible = false

func _physics_process(delta):
	# 1. HANDLE KNOCKBACK DECAY
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

	if is_attacking:
		velocity = knockback_velocity 
		move_and_slide()
		return

	# 2. MOVEMENT
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = (direction * speed) + knockback_velocity

	# 3. FACING
	var mouse_pos = get_global_mouse_position()
	if mouse_pos.x < global_position.x:
		animated_sprite_2d.flip_h = true
	else:
		animated_sprite_2d.flip_h = false

	# 4. ANIMATION & VFX MANAGEMENT
	var current_speed = velocity.length()
	
	# If sliding fast due to knockback
	if current_speed > SLIDE_THRESHOLD and knockback_velocity.length() > SLIDE_THRESHOLD:
		# Ensure smoke is emitting
		if particles and not particles.emitting:
			particles.emitting = true
	else:
		# Stop smoke if we slowed down or are just walking normally
		if particles and particles.emitting:
			particles.emitting = false
			
		if direction != Vector2.ZERO:
			play_anim("run")
		else:
			play_anim("idle")
		
	# 5. ATTACK
	if Input.is_action_just_pressed("attack"):
		start_attack()

	move_and_slide()

func take_damage(amount: int, source_pos: Vector2, attacker: Node = null):
	# A. CHECK INVULNERABILITY
	if is_invulnerable:
		return

	# --- NEW: FRIENDLY FIRE CHECK ---
	# If the attacker exists and is in the 'player' group, ignore the damage
	if attacker and attacker.is_in_group("player"):
		return

	# --- DEFENSE CALCULATION ---
	var reduced_damage = max(1, amount - defense)
	
	hp -= reduced_damage
	print("%s took %d damage (Mitigated %d). HP: %s" % [name, reduced_damage, amount - reduced_damage, hp])
	
	if vfx:
		vfx.visible = true
		vfx.frame = 0
		vfx.play("slash")
	
	if hp <= 0:
		die()
		return

	if source_pos != Vector2.ZERO:
		var knockback_dir = (global_position - source_pos).normalized()
		knockback_velocity = knockback_dir * knockback_strength
		
		if particles:
			particles.rotation = knockback_dir.angle() + PI 
			particles.emitting = true

	flash_hurt_effect()
	shake_camera()
	start_invulnerability()

func start_invulnerability(blink = true):
	is_invulnerable = true
	
	# Create a blinking effect
	var blink_timer = 0.0
	var duration = invulnerability_time
	
	while blink_timer < duration and blink:
		# Toggle visibility every 0.1 seconds
		animated_sprite_2d.visible = !animated_sprite_2d.visible
		await get_tree().create_timer(0.1).timeout
		blink_timer += 0.1
	
	# Reset
	animated_sprite_2d.visible = true
	is_invulnerable = false

func flash_hurt_effect():
	# Flash pure Red/White
	modulate = Color(0.7, 0, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, invulnerability_time/2)

func shake_camera():
	# Attempt to find a Camera2D child to shake
	var camera = find_child("Camera2D")
	if camera:
		# Simple random offset shake
		var original_offset = camera.offset
		var shake_strength = 5.0
		for i in range(10):
			camera.offset = original_offset + Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
			await get_tree().create_timer(0.02).timeout
		camera.offset = original_offset

# --- CORE ATTACK LOGIC ---
func start_attack():
	is_attacking = true
	
	# 1. Calculate Direction
	var mouse_pos = get_global_mouse_position()
	var attack_vector = (mouse_pos - global_position)
	var attack_dir = attack_vector.normalized()
	
	# 2. Apply Recoil (Kickback)
	# We push the player in the OPPOSITE direction of the attack
	knockback_velocity = -attack_dir * recoil_strength
	
	# _physics_process automatically sets velocity = knockback_velocity while is_attacking is true.

	# 3. Visuals & Hitbox
	weapon_pivot.look_at(mouse_pos)
	play_attack_animation(attack_vector)
	
	await get_tree().create_timer(0.2).timeout
	
	var bodies = attack_area.get_overlapping_bodies()
	var is_critical = randf() <= crit_chance
	var final_damage = damage
	if is_critical: final_damage *= crit_multiplier
	
	var hit_count = 0 
	for body in bodies:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(final_damage, global_position, is_critical)
			hit_count += 1
	
	if is_critical and hit_count > 0:
		freeze_frame(0.05, 0.15)
	elif hit_count > 1:
		freeze_frame(0.1, 0.1)

func freeze_frame(time_scale: float, duration: float):
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func play_attack_animation(diff: Vector2):
	if abs(diff.y) > abs(diff.x):
		if diff.y < 0: play_anim("attack_up")
		else: play_anim("attack_down")
	else:
		play_anim("attack_side")
		animated_sprite_2d.flip_h = (diff.x < 0)

func play_anim(anim_name: String):
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _on_animation_finished():
	if animated_sprite_2d.animation.begins_with("attack"):
		is_attacking = false

func die():
	if is_dead: return # Prevent double death
	
	print("%s Died!" % [name])
	is_dead = true
	
	# Emit signal so PartyManager knows to switch
	character_died.emit(self)
	
	# 1. VISUALS & INPUT
	visible = false
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	# 2. PHYSICS
	# Disable body collision so enemies/players can walk through the dead spot
	if collision_shape_2d:
		collision_shape_2d.set_deferred("disabled", true)
	
	# Disable weapon hitbox so the ghost doesn't accidentally kill people
	if collision_shape_2d_attack:
		collision_shape_2d_attack.set_deferred("disabled", true)

func receive_heal(amount: int):
	# 1. Apply Health Math
	hp = min(hp + amount, max_hp)
	print("%s was healed for %d! HP: %d" % [name, amount, hp])
	
	# 2. Visuals
	# Flash Green
	modulate = Color(0, 1, 0) 
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	
	# 3. Play the VFX requested
	if vfx:
		vfx.visible = true
		vfx.frame = 0
		# You mentioned the animation is called "play" or you want to play it.
		# Ideally this animation is named "heal", but here is "play" as requested:
		if vfx.sprite_frames.has_animation("heal"): 
			vfx.play("heal")
		else:
			vfx.play("default") # Fallback

func reset_visuals():
	# 1. Hide damage VFX
	if vfx:
		vfx.visible = false
		vfx.stop()
	
	# 2. Reset color (in case they were flashing red/green)
	modulate = Color.WHITE
	
	# 3. Stop particles
	if particles:
		particles.emitting = false
	
	# 4. Reset Knockback (optional, prevents sliding when swapping in)
	knockback_velocity = Vector2.ZERO
