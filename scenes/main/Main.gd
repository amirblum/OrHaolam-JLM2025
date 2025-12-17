extends Node2D

func _process(_delta: float) -> void:
	# Close the application when Escape is pressed
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
