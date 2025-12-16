extends Area2D

@export var speed = 300.0
@export var damage = 15
@export var blast_radius = 50.0

var target_pos: Vector2
var velocity: Vector2
var has_exploded = false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var vfx: AnimatedSprite2D = $vfx

func start(start_pos: Vector2, _target_pos: Vector2):
	global_position = start_pos
	target_pos = _target_pos
	
	# Ensure explosion is hidden initially
	if vfx:
		vfx.visible = false
	
	# Calculate velocity to move toward target
	velocity = global_position.direction_to(target_pos) * speed
	
	# Juice: Spin the bomb while flying
	var tween = create_tween().set_loops()
	tween.tween_property(animated_sprite_2d, "rotation", 6.28, 0.5).as_relative()
	
	# Play default animation (e.g. ticking or flashing)
	if animated_sprite_2d.sprite_frames.has_animation("default"):
		animated_sprite_2d.play("default")

func _physics_process(delta):
	if has_exploded: return

	# 1. Move Bomb
	global_position += velocity * delta
	
	# 2. Check if arrived at target location
	if global_position.distance_to(target_pos) < 10.0:
		explode()

func explode():
	if has_exploded: return
	has_exploded = true
	
	# 1. Visuals: Swap Bomb for Explosion
	animated_sprite_2d.visible = false 
	
	if vfx:
		vfx.visible = true
		vfx.frame = 0 # Reset to first frame
		vfx.play("explode")
	
	# 2. Deal Area Damage
	var potential_targets = get_tree().get_nodes_in_group("player")
	
	for body in potential_targets:
		var dist = global_position.distance_to(body.global_position)
		if dist <= blast_radius:
			if body.has_method("take_damage"):
				# Pass global_position as source for correct knockback direction
				body.take_damage(damage, global_position, self)
				print("Bomb hit player!")

	# 3. Cleanup: Wait for explosion animation to finish
	if vfx and vfx.sprite_frames.has_animation("explode"):
		await vfx.animation_finished
	else:
		# Fallback if animation is missing or fails
		await get_tree().create_timer(0.5).timeout
		
	queue_free()

func _on_body_entered(body):
	# Explode immediately if we hit the player or a wall directly
	if not has_exploded:
		if body.is_in_group("player") or body is TileMap:
			explode()
