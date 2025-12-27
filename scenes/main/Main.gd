extends Node2D

@export var DEBUG: bool = false

# Total number of persons to use for audio percentage calculation
@export var total_persons_for_audio: int = 100

# Percentage for audio layering (0.0 to 100.0) - calculated from light state persons
var audio_percentage: float = 0.0

@onready var persons_container: Node2D = get_node("Persons")
@onready var cities_container: Node2D = get_node("Cities")
var audio_manager: Node = null  # Will be initialized in _ready() to avoid @onready issues in web builds
var _debug_scene: PackedScene = null  # Will be loaded only if needed and exists

# Array to track all Person instances
var persons: Array[Node2D] = []

func _ready() -> void:
	await get_tree().process_frame
	
	# Get audio_manager directly (avoid @onready issues in web builds)
	audio_manager = get_node_or_null("AudioManager")
	
	_connect_city_signals()
	
	# Initialize audio manager with current percentage
	if audio_manager:
		audio_manager.set_percentage(audio_percentage)
	
	if DEBUG:
		# Load debug scene only if it exists (may not be in web builds)
		if _debug_scene == null:
			_debug_scene = load("res://scenes/debug/Debug.tscn") as PackedScene
		
		if _debug_scene != null:
			var dbg := _debug_scene.instantiate()
			dbg.name = "Debug"
			add_child(dbg)
			# Ensure it sits after Player in the tree; visual overlay is handled by CanvasLayer in Debug.gd.
			move_child(dbg, get_child_count() - 1)

func _connect_city_signals() -> void:
	for city in cities_container.get_children():
		if city is City:
			if city.person_spawned.is_connected(_on_person_spawned):
				city.person_spawned.disconnect(_on_person_spawned)
			city.person_spawned.connect(_on_person_spawned)

func _on_person_spawned(person: Node2D) -> void:
	add_person(person)

# Add a person to the persons layer and register it in the array
func add_person(person: Node2D) -> void:
	if person == null or not is_instance_valid(person):
		return
	
	if person in persons or person.get_parent() == persons_container:
		return
	
	persons_container.add_child(person)
	persons.append(person)
	
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
	if not audio_manager:
		audio_manager = get_node_or_null("AudioManager")
	
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
