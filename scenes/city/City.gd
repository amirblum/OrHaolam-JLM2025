extends Node2D
class_name City

# Signal emitted when a person is spawned
signal person_spawned(person: Node2D)

# Preload the person scene
@onready var person_scene = preload("res://scenes/person/Person.tscn")

# Export variables for configuration
@export var spawn_rate: float = 1.0  # persons per second
@export var city_gen_radius: float = 50.0  # spawn radius from city
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

func _spawn_person() -> void:
	# Instantiate Person scene
	var person := person_scene.instantiate()
	
	# Calculate random position within city_gen_radius from city position
	var angle := randf() * TAU  # Random angle in radians
	var distance := randf() * city_gen_radius  # Random distance within radius
	var offset := Vector2(cos(angle), sin(angle)) * distance
	
	# Set person's global position
	person.global_position = global_position + offset
	
	# Emit signal - Main will handle adding to the Persons container
	person_spawned.emit(person)
