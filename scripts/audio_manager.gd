extends Node

# Create a dictionary to hold your sounds for easy access
var sounds = {
	"switch": preload("res://assets/audio/switch.wav"),
	"woosh": preload("res://assets/audio/woosh.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"crit": preload("res://assets/audio/crit.wav"),
	"fire": preload("res://assets/audio/fire.wav"),
	"grass": preload("res://assets/audio/grass.wav"),
	"dash": preload("res://assets/audio/dash.wav"),
	"torch": preload("res://assets/audio/torch.wav"),
	"enemy_death": preload("res://assets/audio/enemy_death.wav"),
	"heal": preload("res://assets/audio/heal.wav"),
	"healing": preload("res://assets/audio/healing.wav"),
	"hurt": preload("res://assets/audio/hurt.wav"),
	"tnt_throw": preload("res://assets/audio/tnt_throw.wav"),
	"tnt_explode": preload("res://assets/audio/tnt_explode.wav"),
	"exclamation": preload("res://assets/audio/exclamation.wav"),
}

const POOL_SIZE = 8
var players: Array[AudioStreamPlayer] = []

func _ready():
	# Create the pool of players dynamically
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play_sfx(sound_name: String, pitch_randomization: float = 0.0, volume_db: float = -5.0):
	if not sounds.has(sound_name):
		print("Sound not found: ", sound_name)
		return

	# 1. Find a player that isn't busy
	var chosen_player = _get_available_player()
	
	# 2. Setup and Play
	chosen_player.stream = sounds[sound_name]
	chosen_player.volume_db = volume_db
	
	if pitch_randomization > 0:
		chosen_player.pitch_scale = randf_range(1.0 - pitch_randomization, 1.0 + pitch_randomization)
	else:
		chosen_player.pitch_scale = 1.0
		
	chosen_player.play()

func _get_available_player() -> AudioStreamPlayer:
	# Loop through our pool to find a player that is not playing
	for p in players:
		if not p.playing:
			return p
	
	# If all 8 are busy, interrupt the very first one (oldest sound)
	# This keeps the game from crashing or staying silent during chaos
	return players[0]
