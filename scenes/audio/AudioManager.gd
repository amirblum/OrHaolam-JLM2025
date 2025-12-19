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
	# Set initial volumes immediately after setup to prevent all tracks playing at full volume
	_update_tracks()

func _setup_audio_players() -> void:
	# Create an AudioStreamPlayer for each track
	for i in range(tracks.size()):
		var player := AudioStreamPlayer.new()
		player.name = "Track_%d" % (i + 1)
		player.stream = tracks[i]
		player.autoplay = false
		# Set initial volume to muted - will be updated by _update_tracks()
		player.volume_db = -80.0
		
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
	# Track 0 volume decreases logarithmically from 100% to 0% after reaching middle threshold
	if _audio_players.size() > 0:
		# Calculate middle threshold (50% or threshold of middle track)
		var middle_threshold: float = 50.0
		if _track_thresholds.size() > 0:
			var middle_index := int(_track_thresholds.size() / 2.0)
			if middle_index < _track_thresholds.size():
				middle_threshold = _track_thresholds[middle_index]
		
		if percentage < middle_threshold:
			# Before middle - keep at full volume
			_audio_players[0].volume_db = 0.0
		else:
			# After middle - fade out logarithmically
			# Map percentage from [middle_threshold, 100] to [0.0, 1.0]
			var fade_range: float = 100.0 - middle_threshold
			if fade_range > 0.0:
				var fade_factor: float = (percentage - middle_threshold) / fade_range  # 0.0 to 1.0
				# Logarithmic fade: convert linear factor to logarithmic decibel fade
				# Use logarithmic curve for smooth perceived volume fade
				var linear_volume: float = 1.0 - fade_factor  # 1.0 to 0.0
				# Clamp to avoid log(0) and convert to decibels
				linear_volume = max(linear_volume, 0.0001)  # Minimum to avoid log(0)
				_audio_players[0].volume_db = 20.0 * log(linear_volume) / log(10.0)  # log10 conversion
			else:
				_audio_players[0].volume_db = -80.0
	
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
