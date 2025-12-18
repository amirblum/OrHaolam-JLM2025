extends Node2D

@export var light_decay_step: float = 0.1
@export var click_impact_step: float = 0.1
@export var auto_click_rate_step: float = 0.5

var player: Node = null

var _label: Label

func _ready() -> void:
	player = _find_player()
	if player == null:
		push_warning("DEBUG: Could not find Player node.")

	# Minimal on-screen overlay so you can see values without a console.
	var layer := CanvasLayer.new()
	layer.name = "DebugUI"
	layer.layer = 100
	add_child(layer)

	_label = Label.new()
	_label.name = "Info"
	_label.position = Vector2(12, 12)
	layer.add_child(_label)

	_update_label()

func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = _find_player()
	_update_label()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var e := event as InputEventKey
	if e.is_echo() or not e.pressed:
		return

	match e.keycode:
		KEY_P:
			_toggle_bool(&"hold_enable")
		KEY_O:
			_toggle_bool(&"auto_click")
		KEY_Q:
			_add_float(&"lightDecay", -light_decay_step, 0.0)
		KEY_A:
			_add_float(&"lightDecay", light_decay_step, 0.0)
		KEY_W:
			_add_float(&"clickImpact", -click_impact_step, 0.0)
		KEY_S:
			_add_float(&"clickImpact", click_impact_step, 0.0)
		KEY_E:
			_add_float(&"auto_click_rate", -auto_click_rate_step, 0.1)
		KEY_D:
			_add_float(&"auto_click_rate", auto_click_rate_step, 0.1)
		KEY_T:
			_spawn_test_circle()
		_:
			return

	_update_label()

func _toggle_bool(prop: StringName) -> void:
	if player == null or not is_instance_valid(player):
		return
	var v := bool(player.get(prop))
	player.set(prop, not v)

func _add_float(prop: StringName, delta: float, min_value: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var v := float(player.get(prop))
	v = maxf(min_value, v + delta)
	player.set(prop, v)

func _update_label() -> void:
	if _label == null:
		return
	if player == null or not is_instance_valid(player):
		_label.text = "DEBUG\nPlayer not found"
		return
	_label.text = _status_text()

func _status_text() -> String:
	return (
		"DEBUG\n"
		+ "P: hold_enable = %s\n" % str(player.get("hold_enable"))
		+ "O: auto_click = %s\n" % str(player.get("auto_click"))
		+ "Q/A: lightDecay = %.2f\n" % float(player.get("lightDecay"))
		+ "W/S: clickImpact = %.2f\n" % float(player.get("clickImpact"))
		+ "E/D: auto_click_rate = %.2f\n" % float(player.get("auto_click_rate"))
		+ "T: spawn TestCircle\n"
	)

func _find_player() -> Node:
	# Preferred: Debug is instanced under Main, so Player is a sibling.
	var p := get_parent()
	if p != null:
		var sibling := p.get_node_or_null("Player")
		if sibling != null:
			return sibling

	# Fallback (older debug-root layout / other instancing patterns)
	var from_here := get_node_or_null("Main/Player")
	if from_here != null:
		return from_here

	var scene := get_tree().current_scene
	if scene != null:
		var direct := scene.get_node_or_null("Player")
		if direct != null:
			return direct
		var any := scene.find_child("Player", true, false)
		if any != null:
			return any

	return null

func _spawn_test_circle() -> void:
	if player == null or not is_instance_valid(player):
		push_warning("DEBUG: Cannot spawn TestCircle, player not found.")
		return
	
	var viewport := get_viewport_rect().size
	var circle := TestCircle.new()
	circle.position = Vector2(randf_range(0, viewport.x), randf_range(0, viewport.y))
	circle.radius = randf_range(5.0, 100.0)
	circle.player_ref = player
	add_child(circle)
	print("DEBUG: TestCircle spawned at ", circle.position, " with radius ", circle.radius)

# ============================================================================
# TestCircle: visualizes light_state query result
# ============================================================================

class TestCircle extends Node2D:
	var radius: float = 20.0
	var player_ref: Node = null
	var light_value: float = 0.0
	
	func _process(_delta: float) -> void:
		if player_ref == null or not is_instance_valid(player_ref):
			queue_free()
			return
		
		if not player_ref.has_method("light_state"):
			return
		
		light_value = player_ref.call("light_state", global_position, radius)
		queue_redraw()
	
	func _draw() -> void:
		var color := Color.WHITE
		match light_value:
			0.0:
				color = Color(0.3, 0.3, 0.3, 0.8) # grey (dark)
			0.5:
				color = Color(0.7, 0.7, 0.7, 0.8) # mid-grey (partial)
			1.0:
				color = Color(1.0, 1.0, 1.0, 0.8) # white (lit)
		
		# Draw filled circle
		draw_circle(Vector2.ZERO, radius, color)
		
		# Draw outline for visibility
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 2.0)
