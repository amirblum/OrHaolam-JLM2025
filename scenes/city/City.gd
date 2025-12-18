extends Node2D
class_name City

# Signal emitted when a person is spawned
signal person_spawned(person: Node2D)

# Preload the person scene
@onready var person_scene = preload("res://scenes/person/Person.tscn")

# Reference to the visual ColorRect
@onready var visual: ColorRect = $Visual

# Export variables for configuration
@export var spawn_rate: float = 1.0  # persons per second
@export var spawn_rate_variance: float = 0.05  # random offset range (-x to x) for time until next spawn
@export var max_spawn_radius: float = 50.0  # maximum spawn radius from city
@export var min_spawn_radius: float = 10.0  # minimum spawn radius from city
@export var city_name: String = "City"  # city name 
@export var light_check_radius: float = 50.0  # radius for checking light state

# Timer accumulator for spawn rate
var _spawn_accum := 0.0

# Light state: 0.0 (dark), 0.5 (partial), 1.0 (fully lit)
var light_state: float = 0.0

# Reference to the player node
var _player: Node2D = null

func _ready() -> void:
	# Get reference to the player node
	_player = get_node_or_null("/root/Main/Player")
	if _player == null:
		push_warning("City: Could not find Player node at /root/Main/Player")

func _process(delta: float) -> void:
	# Update light state from player's light_state method
	if _player != null and _player.has_method("light_state"):
		light_state = _player.call("light_state", global_position, light_check_radius)

	if light_state >= 1.0:
		visual.color = Color(0.85, 0.85, 0.85, 1.0)
	
	if light_state <= 0:
		visual.color = Color(1, 0.2, 0.8, 1)
	
	if spawn_rate <= 0.0:
		return
	
	var period := 1.0 / spawn_rate
	if light_state < 1.0:
		_spawn_accum += delta
	
	while _spawn_accum >= period:
		_spawn_accum -= period
		_spawn_person()
		# Add random variance to the time until next spawn
		var variance_offset := randf_range(-spawn_rate_variance, spawn_rate_variance)
		_spawn_accum += variance_offset

func _spawn_person() -> void:
	# Instantiate Person scene
	var person := person_scene.instantiate()
	
	# Calculate random position between min_spawn_radius and max_spawn_radius from city position
	var angle := randf() * TAU  # Random angle in radians
	var max_distance := maxf(min_spawn_radius, max_spawn_radius)  # Ensure max >= min
	var distance := min_spawn_radius + randf() * (max_distance - min_spawn_radius)  # Random distance in range [min, max]
	var offset := Vector2(cos(angle), sin(angle)) * distance
	
	# Set person's global position
	person.global_position = global_position + offset
	
	# Emit signal - Main will handle adding to the Persons container
	person_spawned.emit(person)
