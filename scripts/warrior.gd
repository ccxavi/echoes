extends Character

func _ready():
	super._ready()
	
	# override default stats
	speed = 260.0
	max_hp = 100
	defense = 6
	crit_chance = 0.3
	damage = 100
	
	hp = max_hp
