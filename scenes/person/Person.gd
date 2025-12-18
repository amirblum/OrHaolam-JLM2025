extends Node2D
class_name Person

# Movement configuration (PRD parameters)
@export var move_pulse_speed: float = 1.5 # Seconds between movement pulses, PRD `movePulseSpeed`
@export var walk_distance: float = 15.0 # Distance moved per pulse, PRD `walkDistance`
@export var drunkness: float = 0.4 # Random angle offset factor (radians), PRD `drunkness`
@export var lightSteal: float = 10.0 # Light stolen when Person touches Jerusalem, PRD `lightSteal`
@export var PersonRadius: float = 10.0

# Reference to the visual ColorRect
@onready var visual: ColorRect = $Visual

# Internal state
var _pulse_accum := 0.0
var _player_node: Node2D = null
var state: float = 0.0 # Light state: 0.0 = dark, 0.5 = partial, 1.0 = engulfed

func _ready() -> void:
	# Get reference to the player node
	_player_node = get_node_or_null("/root/Main/Player")
	if _player_node == null:
		push_warning("Person: Could not find Player node at /root/Main/Player")

func _process(delta: float) -> void:
	# Update light state from player's light_state method
	if _player_node != null and _player_node.has_method("light_state"):
		state = _player_node.call("light_state", global_position, PersonRadius)
	
	# Update visual color based on state
	if state >= 1.0:
		visual.color = Color(0.8, 0.8, 0.8, 1)
	
	if state <= 0:
		visual.color = Color(1, 0.2, 0.8, 1)
	
	# Only move if we're in dark state (for now, always move - state management comes later)
	# Movement pulses occur every move_pulse_speed seconds
	if move_pulse_speed <= 0.0:
		return
	
	var period := move_pulse_speed
	if state < 1.0:
		_pulse_accum += delta
	
	while _pulse_accum >= period:
		_pulse_accum -= period
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
	# Placeholder for light stealing - decrease lightBank by lightSteal
	# TODO: Implement proper lightBank access and decrease
	if _player_node != null and _player_node.has_method("decrease_light_bank"):
		_player_node.call("decrease_light_bank", lightSteal)
