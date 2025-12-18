extends Node2D
class_name City

# Signal emitted when a person is spawned
signal person_spawned(person: Node2D)

# Preload the person scene
@onready var person_scene = preload("res://scenes/person/Person.tscn")

# Export variables for configuration
@export var spawn_rate: float = 1.0  # persons per second
@export var spawn_rate_variance: float = 0.05  # random offset range (-x to x) for time until next spawn
@export var max_spawn_radius: float = 50.0  # maximum spawn radius from city
@export var min_spawn_radius: float = 10.0  # minimum spawn radius from city
@export var city_name: String = "City"  # city name 

# Timer accumulator for spawn rate
var _spawn_accum := 0.0

func _process(delta: float) -> void:
	if spawn_rate <= 0.0:
		return
	
	var period := 1.0 / spawn_rate
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
