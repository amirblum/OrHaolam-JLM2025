extends Node2D

@export var DEBUG: bool = false

@onready var _debug_scene := preload("res://scenes/debug/Debug.tscn")
@onready var persons_container: Node2D = get_node("Persons")
@onready var cities_container: Node2D = get_node("Cities")

# Array to track all Person instances
var persons: Array[Node2D] = []

func _ready() -> void:
	# Connect to all City signals for person spawning
	_connect_city_signals()
	
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
	# Close the application when Escape is pressed
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
