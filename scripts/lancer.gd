extends Character

# --- CONFIGURATION ---
@export_group("Lancer Charge")
@export var lunge_cooldown_time: float = 1.5 

const CHARGE_THRESHOLD = 0.35      
const MAX_CHARGE_TIME = 1.2        
const CHARGE_WALK_SPEED = 0.4  
const LUNGE_SPEED = 1000.0  
const LUNGE_DAMAGE_MULT = 2.5      

# --- STATE ---
var is_charging_attack = false     
var can_lunge = true               
var charge_start_time = 0.0
var charge_tween: Tween

func _ready():
	super._ready()
	
	# Override stats
	speed = 310.0
	max_hp = 110
	defense = 4
	damage = 8        
	crit_chance = 0.25
	hp = max_hp
	
	if weapon_pivot:
		weapon_pivot.scale = Vector2(1.3, 1.3)

# --- INPUT HANDLING ---
func _unhandled_input(event):
	if is_attacking or is_dead: return

	# 1. BLOCK DASH IF CHARGING
	# If we are charging the spear, we ignore the dash input so we don't accidentally cancel the charge
	if is_charging_attack and event.is_action_pressed("dash"):
		return

	# 2. LET PARENT HANDLE DASH
	# This triggers start_universal_dash() in character.gd
	super._unhandled_input(event)

	# 3. LANCER SPECIFIC: CHARGE ATTACK
	# Only allow charging if we aren't dashing (is_dashing is inherited)
	if event.is_action_pressed("attack") and can_lunge and not is_dashing:
		start_charging()
	
	if event.is_action_released("attack"):
		release_charge()

# --- PHYSICS ---
func _physics_process(delta):
	# 1. PRIORITY: DASH (Inherited)
	if is_dashing:
		# Call parent physics to handle dash movement & ghost spawning
		super._physics_process(delta) 
		return

	# 2. PRIORITY: CHARGING (Lancer Specific)
	if is_charging_attack:
		handle_charging_movement(delta)
	else:
		# 3. PRIORITY: NORMAL MOVEMENT (Inherited)
		super._physics_process(delta)

# --- DAMAGE RESPONSE ---
func take_damage(amount: int, source_pos: Vector2, attacker: Node = null):
	if is_dashing: return # Invulnerable during dash (handled in parent logic, but good double check)
	
	# If hit while charging, cancel the charge
	if is_charging_attack:
		cancel_charge()
	
	super.take_damage(amount, source_pos, attacker)

# --- CHARGE MECHANIC (Lancer Specific) ---
func start_charging():
	is_charging_attack = true
	charge_start_time = Time.get_ticks_msec() / 1000.0
	
	modulate = Color(0.5, 0.8, 1) 
	
	if charge_tween: charge_tween.kill()
	charge_tween = create_tween()
	charge_tween.tween_property(self, "modulate", Color(0.2, 0.2, 3.0), MAX_CHARGE_TIME)

func handle_charging_movement(_delta):
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * (speed * CHARGE_WALK_SPEED)
	
	var mouse_pos = get_global_mouse_position()
	animated_sprite_2d.flip_h = (mouse_pos.x < global_position.x)
	weapon_pivot.look_at(mouse_pos)
	
	if direction != Vector2.ZERO:
		play_anim("run")
		animated_sprite_2d.speed_scale = 0.5
	else:
		play_anim("idle")
		animated_sprite_2d.speed_scale = 1.0

	move_and_slide()

func cancel_charge():
	is_charging_attack = false
	if charge_tween: charge_tween.kill()
	modulate = Color.WHITE
	animated_sprite_2d.speed_scale = 1.0

func release_charge():
	if not is_charging_attack: return
	
	var hold_duration = (Time.get_ticks_msec() / 1000.0) - charge_start_time
	is_charging_attack = false
	
	if charge_tween: charge_tween.kill()
	modulate = Color.WHITE
	animated_sprite_2d.speed_scale = 1.0
	
	if hold_duration < CHARGE_THRESHOLD:
		# Short Tap: Normal Poke (Inherited from Character)
		super.start_attack()
	else:
		# Long Hold: SPECIAL LUNGE
		perform_lunge_attack(hold_duration)

# --- LUNGE ATTACK & KILL RESET ---
func perform_lunge_attack(charge_time):
	is_attacking = true
	can_lunge = false 
	
	AudioManager.play_sfx("woosh", 0.1, 5.0)
	
	var mouse_pos = get_global_mouse_position()
	var attack_vector = (mouse_pos - global_position).normalized()
	
	weapon_pivot.look_at(mouse_pos)
	play_attack_animation(attack_vector)
	
	var power_ratio = min(charge_time / MAX_CHARGE_TIME, 1.0)
	var final_damage = damage * LUNGE_DAMAGE_MULT * (0.5 + (power_ratio * 0.5))
	
	knockback_velocity = attack_vector * LUNGE_SPEED
	
	if particles:
		particles.emitting = true
		particles.amount = 20
		particles.color = Color(0, 0.5, 1)
	
	var lunge_duration = 0.25 
	var timer = 0.0
	var enemies_hit = []
	var kill_confirmed = false 
	
	while timer < lunge_duration:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemy") and body not in enemies_hit and body.has_method("take_damage"):
				var is_critical = randf() <= crit_chance
				var actual_damage = final_damage * crit_multiplier if is_critical else final_damage
				
				body.take_damage(actual_damage, global_position, is_critical)
				enemies_hit.append(body)
				
				if "hp" in body and body.hp <= 0:
					kill_confirmed = true
				
				AudioManager.play_sfx("crit" if is_critical else "hurt", 0.1)
				freeze_frame(0.05, 0.1)
		
		timer += get_process_delta_time()
		await get_tree().process_frame
		
	knockback_velocity = Vector2.ZERO
	is_attacking = false
	if particles: 
		particles.emitting = false
		particles.color = Color.WHITE

	if kill_confirmed:
		print("KILL RESET TRIGGERED!")
		can_lunge = true
		modulate = Color(2, 2, 2)
		var t = create_tween()
		t.tween_property(self, "modulate", Color.WHITE, 0.2)
	else:
		print("Lunge on Cooldown...")
		await get_tree().create_timer(lunge_cooldown_time).timeout
		can_lunge = true
