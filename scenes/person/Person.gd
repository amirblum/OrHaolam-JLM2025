extends Sprite2D
class_name Person

# Movement configuration (PRD parameters)
@export var move_pulse_speed: float = 1.2 # Seconds between movement pulses, PRD `movePulseSpeed`
@export var move_pulse_speed_variance: float = 0.5 # Variance in movement pulse speed, PRD `movePulseSpeedVariance`
@export var walk_distance: float = 7.8 # Distance moved per pulse, PRD `walkDistance`
@export var drunkness: float = 2 # Random angle offset factor (radians), PRD `drunkness`
@export var lightSteal: float = 30.0 # Light stolen when Person touches Jerusalem, PRD `lightSteal`
@export var PersonRadius: float = 5.0
@export var happy_time: float = 0.0 # Time in light before a Person becomes happy
@export var dancing: bool = false # If true, the Person is dancing
@export var dancing_light: float = 14.0 # Light added to lightBank per second by each happy Person

# Texture resources for dark and light states
@export var dark_texture: Texture2D
@export var dark_text_2: Texture2D
@export var light_texture: Texture2D

# Internal state
var animToggle = false
var animSwitch = 0.3
var animAccum = 0
var _pulse_accum := 0.0
var _happy_accum := 0.0
var _player_node: Node2D = null
var state: float = 0.0 # Light state: 0.0 = dark, 0.5 = partial, 1.0 = engulfed
var period := move_pulse_speed + randf_range(-move_pulse_speed_variance, move_pulse_speed_variance)

func _ready() -> void:
	# Get reference to the player node
	_player_node = get_node_or_null("/root/Main/Player")
	if _player_node == null:
		push_warning("Person: Could not find Player node at /root/Main/Player")
	# Set dark texture on start
	texture = dark_texture

func _process(delta: float) -> void:
	
	# Update light state from player's light_state method
	if _player_node != null and _player_node.has_method("light_state"):
		state = _player_node.call("light_state", global_position, PersonRadius)
	
	# Update sprite texture based on state
	if state >= 1.0:
		# Fully lit - use light texture
		texture = light_texture
		_happy_accum += delta
		if _happy_accum >= happy_time:
			if not dancing:
				dancing = true
				_player_node.lightBank += dancing_light
	if dancing:
		rotation_degrees += randf_range(-4,4)
	else:
		rotation_degrees = 0.0	
	if state <= 0:
		# Dark or partially lit - use dark texture
		texture = getTexture()
		dancing = false
		_happy_accum = 0.0
	
	
	
	if state < 1.0:
		_pulse_accum += delta
	
	while _pulse_accum >= period:
		_pulse_accum -= period
		period = move_pulse_speed + randf_range(-move_pulse_speed_variance, move_pulse_speed_variance)
		_attempt_movement_pulse()

func _attempt_movement_pulse() -> void:
	# Get screen center (Jerusalem position)
	var screen_center := get_viewport_rect().size / 2
	
	# Calculate direction toward Jerusalem
	var to_center := screen_center - global_position
	var distance_to_center := to_center.length()
	
	# If already within JerusalemRadius, trigger light stealing and don't move
	if _player_node != null and distance_to_center <= _player_node.player_radius:
		_steal_light()
		return
	
	# Calculate base angle toward Jerusalem
	var base_angle := to_center.angle()
	
	# Add random offset based on drunkness factor
	var random_offset := (randf() - 0.5) * 2.0 * drunkness
	var move_angle := base_angle + random_offset
	
	# Calculate movement vector
	var move_vector := Vector2(cos(move_angle), sin(move_angle)) * walk_distance
	var new_position := global_position + move_vector
	
	# Check if the new position would be within JerusalemRadius
	var new_to_center := screen_center - new_position
	var new_distance := new_to_center.length()
	
	if _player_node != null and new_distance <= _player_node.player_radius:
		# Would enter JerusalemRadius - trigger light stealing instead of moving
		_steal_light()
		return
	
	# Move the Person
	global_position = new_position

func _steal_light() -> void:
	get_tree().paused = true
	var timer := get_tree().create_timer(5.0, true)
	await timer.timeout
	get_tree().paused = false
	get_tree().reload_current_scene()
	if _player_node != null and _player_node.has_method("decrease_light_bank"):
		_player_node.call("decrease_light_bank", lightSteal)
		queue_free()

func getTexture() -> Texture2D:
	animAccum += get_process_delta_time()
	if animAccum > animSwitch:
		animAccum = 0
		animToggle = !animToggle
	if animToggle:
		return dark_text_2
	else:
		return dark_texture
	
	
