extends Node

# Array of audio tracks to play layered
@export var tracks: Array[AudioStream] = []

# Current percentage (0.0 to 100.0) - will be set from Main.gd
var percentage: float = 0.0

# Array to hold AudioStreamPlayer instances for each track
var _audio_players: Array[AudioStreamPlayer] = []

# Track thresholds - calculated based on number of tracks
var _track_thresholds: Array[float] = []

func _ready() -> void:
	_setup_audio_players()
	_calculate_thresholds()

func _setup_audio_players() -> void:
	# Create an AudioStreamPlayer for each track
	for i in range(tracks.size()):
		var player := AudioStreamPlayer.new()
		player.name = "Track_%d" % (i + 1)
		player.stream = tracks[i]
		player.autoplay = false
		player.volume_db = 0.0
		
		# Set loop mode
		if tracks[i] is AudioStreamOggVorbis:
			tracks[i].loop = true
		
		add_child(player)
		_audio_players.append(player)
	
	# Start all tracks playing (they'll be muted/unmuted via volume control)
	for player in _audio_players:
		player.play()

func _calculate_thresholds() -> void:
	_track_thresholds.clear()
	
	if tracks.size() <= 1:
		return
	
	# Calculate thresholds: divide 100% by number of tracks
	# Track 1 always plays (threshold 0.0)
	# Track 2 starts at 100/N, Track 3 at 200/N, etc.
	# Last track starts at (N-1) * 100/N, which is before 100%
	var interval: float = 100.0 / float(tracks.size())
	
	for i in range(1, tracks.size()):
		var threshold: float = float(i) * interval
		_track_thresholds.append(threshold)

func set_percentage(new_percentage: float) -> void:
	percentage = clamp(new_percentage, 0.0, 100.0)
	_update_tracks()

func _update_tracks() -> void:
	# Track 0 always has full volume (threshold 0.0)
	if _audio_players.size() > 0:
		_audio_players[0].volume_db = 0.0
	
	# Update other tracks based on thresholds - control volume instead of play/stop
	for i in range(1, _audio_players.size()):
		var threshold_index := i - 1
		if threshold_index < _track_thresholds.size():
			var threshold := _track_thresholds[threshold_index]
			var player := _audio_players[i]
			
			if percentage >= threshold:
				# Track should be audible - set volume to 0.0 dB (100%)
				player.volume_db = 0.0
			else:
				# Track should be silent - set volume to -80.0 dB (muted)
				player.volume_db = -80.0
