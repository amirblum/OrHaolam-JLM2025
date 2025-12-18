extends Sprite2D
class_name City

# Signal emitted when a person is spawned
signal person_spawned(person: Node2D)

# Preload the person scene
@onready var person_scene = preload("res://scenes/person/Person.tscn")

# Texture resources for dark and light states
@export var dark_texture: Texture2D
@export var light_texture: Texture2D

# Export variables for configuration
@export var spawn_rate: float   # persons per second
@export var spawn_variance: float = 0.05  # random offset range (-x to x) for time until next spawn
@export var max_spawn_radius: float = 50.0  # maximum spawn radius from city
@export var min_spawn_radius: float = 10.0  # minimum spawn radius from city
@export var city_name: String = "City"  # city name 
@export var light_check_radius: float = 50.0  # radius for checking light state

# Timer accumulator for spawn rate
var _spawn_accum := 0.0
var period := spawn_rate

# Light state: 0.0 (dark), 0.5 (partial), 1.0 (fully lit)
var light_state: float = 0.0

# Reference to the player node
var _player: Node2D = null

func _ready() -> void:
	period = spawn_rate/3
	# Get reference to the player node
	_player = get_node_or_null("/root/Main/Player")
	if _player == null:
		push_warning("City: Could not find Player node at /root/Main/Player")
	# Set dark texture on start
	texture = dark_texture
	queue_redraw()

func _draw() -> void:
	# Draw a circle in the background with radius equal to light_check_radius
	draw_circle(Vector2.ZERO, light_check_radius, Color(1.0, 1.0, 1.0, 0.2))

func _process(delta: float) -> void:
	# Update light state from player's light_state method
	if _player != null and _player.has_method("light_state"):
		light_state = _player.call("light_state", global_position, light_check_radius)

	# Update sprite texture based on light state
	if light_state >= 1.0:
		# Fully lit - use light texture
		texture = light_texture
	else:
		# Dark or partially lit - use dark texture
		texture = dark_texture
	
	if light_state >= 0:
		_spawn_accum += delta
	
	if _spawn_accum >= period:
		_spawn_accum = 0
		period = spawn_rate + randf_range(-spawn_variance, spawn_variance)
		_spawn_person()
		

func _spawn_person() -> void:
	# Instantiate Person scene
	var person := person_scene.instantiate()
	
	# Calculate random position between min_spawn_radius and max_spawn_radius from city position
	var angle := randf() * TAU  # Random angle in radians
	var max_distance := maxf(min_spawn_radius, max_spawn_radius)  # Ensure max >= min
	var distance := min_spawn_radius + randf() * (max_distance - min_spawn_radius)  # Random distance in range [min, max]
	var spawn_offset := Vector2(cos(angle), sin(angle)) * distance
	
	# Set person's global position
	person.global_position = global_position + spawn_offset
	
	# Emit signal - Main will handle adding to the Persons container
	person_spawned.emit(person)
