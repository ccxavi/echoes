extends Enemy


func _ready():
	super._ready()
	
	max_hp = 50
	speed = 100
	damage = 8
	attack_cooldown = 1.0
	
	hp = max_hp
