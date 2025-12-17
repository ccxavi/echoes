class_name Character extends CharacterBody2D

# --- SIGNALS ---
signal health_changed(current_hp, max_hp)
signal character_died(character_node)
# This signal is kept for backend logic, even if you reimplement the UI later
signal ability_used(current_cooldown, max_cooldown)

@export_group("Stats")
# --- ADDED FROM OLD CODE (Required for Stats Panel) ---
@export var portrait_img: Texture2D 
# -----------------------------------------------------
@export var max_hp = 100
@export var speed = 300.0
@export var damage = 1 
@export var defense = 0
@export var crit_chance = 0.2
@export var crit_multiplier = 2.0
@export var recoil_strength = 300.0

# --- ADDED FROM OLD CODE (Required for Switching Logic) ---
@export_group("Special Ability")
@export var ability_cooldown_duration = 3.0
# Set this to "Dash" or "Heal" in the Inspector!
@export var ability_name = "None" 
# ---------------------------------------------------------

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
var is_dead = false

const SLIDE_THRESHOLD = 50.0

# Footsteps
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.35 

# --- ADDED FROM OLD CODE (Required for Cooldowns) ---
var ability_timer: Timer

func _ready():
	# --- ADDED FROM OLD CODE ---
	ability_timer = Timer.new()
	ability_timer.one_shot = true
	ability_timer.wait_time = ability_cooldown_duration
	add_child(ability_timer)
	# ---------------------------

	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	
	if vfx:
		vfx.visible = false
		vfx.animation_finished.connect(_on_vfx_finished)
	
	if particles:
		particles.emitting = false

# --- ABILITY LOGIC (Added from Old Code so Manager doesn't crash) ---
func try_use_special_ability():
	if is_dead: return
	
	if not ability_timer.is_stopped():
		print("Ability on Cooldown!")
		return

	if ability_name == "Dash":
		perform_dash()
	elif ability_name == "Heal":
		perform_heal_skill()
	else:
		print("No ability assigned to this character.")
		return

	ability_timer.start()
	emit_signal("ability_used", ability_cooldown_duration, ability_cooldown_duration)

func get_cooldown_status():
	return [ability_timer.time_left, ability_timer.wait_time]

func perform_dash():
	print("Performing Dash!")
	AudioManager.play_sfx("woosh", 0.1) # Added SFX
	var dash_vector = velocity.normalized()
	if dash_vector == Vector2.ZERO: 
		dash_vector = Vector2(-1, 0) if animated_sprite_2d.flip_h else Vector2(1, 0)
	knockback_velocity = dash_vector * (speed * 4.0) 
	if particles: particles.emitting = true

func perform_heal_skill():
	print("Charging Heal!")
	if get_parent().has_method("queue_heal_for_next_switch"):
		get_parent().queue_heal_for_next_switch(50) 
# ------------------------------------------------------------------

func _on_vfx_finished():
	vfx.visible = false

func _physics_process(delta):
	if knockback_velocity != Vector2.ZERO:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

	if is_attacking:
		velocity = knockback_velocity 
		move_and_slide()
		return

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = (direction * speed) + knockback_velocity
	
	var mouse_pos = get_global_mouse_position()
	animated_sprite_2d.flip_h = (mouse_pos.x < global_position.x)

	# ANIMATION, VFX & SOUND
	var current_speed = velocity.length()
	
	if footstep_timer > 0:
		footstep_timer -= delta
	
	if current_speed > SLIDE_THRESHOLD and knockback_velocity.length() > SLIDE_THRESHOLD:
		if particles and not particles.emitting:
			particles.emitting = true
	else:
		if particles and particles.emitting:
			particles.emitting = false
			
		if direction != Vector2.ZERO:
			play_anim("run")
			if footstep_timer <= 0:
				AudioManager.play_sfx("grass", 0.1, -5.0) 
				footstep_timer = FOOTSTEP_INTERVAL
		else:
			play_anim("idle")
		
	if Input.is_action_just_pressed("attack"):
		start_attack()

	move_and_slide()

func take_damage(amount: int, source_pos: Vector2, attacker: Node = null):
	if is_invulnerable: return

	# Friendly Fire Check
	if attacker and attacker.is_in_group("player"): return

	# Defense Calculation
	var reduced_damage = max(1, amount - defense)
	
	hp -= reduced_damage
	AudioManager.play_sfx("hurt", 0.1)
	print("%s took %d damage (Mitigated %d). HP: %s" % [name, reduced_damage, amount - reduced_damage, hp])
	
	health_changed.emit(hp, max_hp) # Ensure UI updates
	
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
	var blink_timer = 0.0
	var duration = invulnerability_time
	
	while blink_timer < duration and blink:
		animated_sprite_2d.visible = !animated_sprite_2d.visible
		await get_tree().create_timer(0.1).timeout
		blink_timer += 0.1
	
	animated_sprite_2d.visible = true
	is_invulnerable = false

func flash_hurt_effect():
	modulate = Color(0.7, 0, 0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, invulnerability_time/2)

func shake_camera():
	var camera = find_child("Camera2D")
	if camera:
		var original_offset = camera.offset
		var shake_strength = 10.0
		for i in range(10):
			camera.offset = original_offset + Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
			await get_tree().create_timer(0.02).timeout
		camera.offset = original_offset

func start_attack():
	is_attacking = true
	AudioManager.play_sfx("woosh", 0.1)
	
	var mouse_pos = get_global_mouse_position()
	var attack_vector = (mouse_pos - global_position)
	var attack_dir = attack_vector.normalized()
	
	# Recoil Logic
	knockback_velocity = -attack_dir * recoil_strength

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
		freeze_frame(0.01, 0.15)
		AudioManager.play_sfx("crit", 0.1)
	elif hit_count > 1:
		freeze_frame(0.001, 0.1)
		AudioManager.play_sfx("crit", 0.1)

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
	if is_dead: return 
	print("%s Died!" % [name])
	is_dead = true
	character_died.emit(self)
	
	visible = false
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	if collision_shape_2d:
		collision_shape_2d.set_deferred("disabled", true)
	if collision_shape_2d_attack:
		collision_shape_2d_attack.set_deferred("disabled", true)

func receive_heal(amount: int):
	hp = min(hp + amount, max_hp)
	print("%s was healed for %d! HP: %d" % [name, amount, hp])
	health_changed.emit(hp, max_hp) # Update UI
	
	modulate = Color(0, 1, 0) 
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	
	if vfx:
		vfx.visible = true
		vfx.frame = 0
		if vfx.sprite_frames.has_animation("heal"): 
			vfx.play("heal")
			AudioManager.play_sfx("healing", 0.1, -10)
		else:
			vfx.play("default")

func reset_visuals():
	if vfx:
		vfx.visible = false
		vfx.stop()
	modulate = Color.WHITE
	if particles:
		particles.emitting = false
	knockback_velocity = Vector2.ZERO
