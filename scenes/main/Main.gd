extends Node2D

@export var DEBUG: bool = false

# Total number of persons to use for audio percentage calculation
@export var total_persons_for_audio: int = 100

# Percentage for audio layering (0.0 to 100.0) - calculated from light state persons
var audio_percentage: float = 0.0

@onready var _debug_scene := preload("res://scenes/debug/Debug.tscn")
@onready var persons_container: Node2D = get_node("Persons")
@onready var cities_container: Node2D = get_node("Cities")
@onready var audio_manager = get_node("AudioManager")

# Array to track all Person instances
var persons: Array[Node2D] = []

func _ready() -> void:
	# Connect to all City signals for person spawning
	_connect_city_signals()
	
	# Initialize audio manager with current percentage
	if audio_manager:
		audio_manager.set_percentage(audio_percentage)
	
	if DEBUG:
		var dbg := _debug_scene.instantiate()
		dbg.name = "Debug"
		add_child(dbg)
		# Ensure it sits after Player in the tree; visual overlay is handled by CanvasLayer in Debug.gd.
		move_child(dbg, get_child_count() - 1)

func _connect_city_signals() -> void:
	# Connect signals for existing cities
	for city in cities_container.get_children():
		if city is City:
			city.person_spawned.connect(_on_person_spawned)

func _on_person_spawned(person: Node2D) -> void:
	add_person(person)

# Add a person to the persons layer and register it in the array
func add_person(person: Node2D) -> void:
	if person == null or not is_instance_valid(person):
		return
	
	persons_container.add_child(person)
	persons.append(person)
	
	# Clean up reference when person is removed
	person.tree_exited.connect(func() -> void:
		persons.erase(person)
	)

# Get the list of all Person instances (for Player/GameManager access)
func get_persons() -> Array[Node2D]:
	return persons

func _process(_delta: float) -> void:
	# Calculate audio percentage based on persons in light state
	_calculate_audio_percentage()
	
	# Update audio manager with calculated percentage
	if audio_manager:
		audio_manager.set_percentage(audio_percentage)
	
	# Close the application when Escape is pressed
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()

func _calculate_audio_percentage() -> void:
	# Count persons in light state (state >= 1.0 means fully lit)
	var light_persons_count: int = 0
	for person in persons:
		if person is Person and person.state >= 1.0:
			light_persons_count += 1
	
	# Calculate percentage: (light persons / total) * 100.0
	if total_persons_for_audio > 0:
		audio_percentage = (float(light_persons_count) / float(total_persons_for_audio)) * 100.0
	else:
		audio_percentage = 0.0
	
	# Clamp to valid range
	audio_percentage = clamp(audio_percentage, 0.0, 100.0)
