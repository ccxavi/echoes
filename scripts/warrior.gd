extends Character

func _ready():
	super._ready()
	
	# override default stats
	speed = 220.0
	max_hp = 100
	defense = 8
	crit_chance = 0.3
	damage = 2
	
	hp = max_hp
