extends Node2D

# Constants for cone behavior
const CONE_RADIUS = 250.0
const CONE_ANGLE = 60.0    # Degrees
const CONE_DURATION = 1.5  # Seconds

# Preload the cone scene
@onready var cone_scene = preload("res://scenes/cone/Cone.tscn")

func _input(event):
	# Listen for mouse button click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			spawn_cone()
	
	# Listen for space bar press
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.pressed and not event.is_echo():
			spawn_cone()

func spawn_cone():
	var cone = cone_scene.instantiate()
	
	# Origin is the center of the screen as per requirements
	var screen_center = get_viewport_rect().size / 2
	
	# Direction is defined by: mouse_position - screen_center
	var mouse_pos = get_global_mouse_position()
	var direction_vector = mouse_pos - screen_center
	
	# If mouse is exactly at center, default to right
	var direction_angle = 0.0
	if direction_vector.length() > 0:
		direction_angle = direction_vector.angle()
	
	# Setup the cone with our constants
	cone.setup(direction_angle, CONE_RADIUS, CONE_ANGLE, CONE_DURATION)
	cone.position = screen_center
	
	# Add to main scene (parent) so it stays in place
	get_parent().add_child(cone)
