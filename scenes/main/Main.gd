extends Node2D

@export var DEBUG: bool = false

@onready var _debug_scene := preload("res://scenes/debug/Debug.tscn")

func _ready() -> void:
	if DEBUG:
		var dbg := _debug_scene.instantiate()
		dbg.name = "Debug"
		add_child(dbg)
		# Ensure it sits after Player in the tree; visual overlay is handled by CanvasLayer in Debug.gd.
		move_child(dbg, get_child_count() - 1)

func _process(_delta: float) -> void:
	# Close the application when Escape is pressed
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
