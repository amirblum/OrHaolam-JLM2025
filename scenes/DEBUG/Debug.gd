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
	var fps := Engine.get_frames_per_second()
	return (
		"DEBUG\n"
		+ "FPS: %d\n" % fps
		+ "P: hold_enable = %s\n" % str(player.get("hold_enable"))
		+ "O: auto_click = %s\n" % str(player.get("auto_click"))
		+ "Q/A: lightDecay = %.2f\n" % float(player.get("lightDecay"))
		+ "W/S: clickImpact = %.2f\n" % float(player.get("clickImpact"))
		+ "E/D: auto_click_rate = %.2f\n" % float(player.get("auto_click_rate"))
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
