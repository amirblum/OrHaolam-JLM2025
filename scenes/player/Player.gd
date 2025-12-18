extends Node2D

# Constants for cone behavior
@export var coneRadius: float = 1200.0
@export var clickImpact: float = 4.5 # Degrees, PRD `clickImpact`
@export var minClickDist: float = 2.0 # Minimum distance from center to register a click
@export var lightDecay: float = 5.0 # Deg/sec, PRD `lightDecay`
@export var hold_enable: bool = false # Upgrade: allows click-and-hold repeating ticks
@export var auto_click_rate: float = 12.0 # Clicks per second while holding / auto-clicking
@export var auto_click: bool = false # If true, auto-click even when not holding

const _MERGE_EPS_RAD := 0.00001

static func _unwrap_near(a: float, ref: float) -> float:
	# Return an equivalent angle to `a` that is closest to `ref`.
	return ref + wrapf(a - ref, -PI, PI)

# Preload the cone scene
@onready var cone_scene = preload("res://scenes/cone/Cone.tscn")

# Layer/container for all active beam instances (cones)
@onready var beams_layer: Node2D = get_node_or_null("Beams")

# Accessible memory: keep references to currently-active beam instances.
var beams: Array[Node2D] = []

var _mouse_down := false
var _space_down := false
var _click_accum := 0.0

func _ready() -> void:
	# Ensure there is always a Beams container, even if the scene wasn't set up yet.
	if beams_layer == null:
		beams_layer = Node2D.new()
		beams_layer.name = "Beams"
		add_child(beams_layer)

func _process(delta: float) -> void:
	# Single click is always available (handled in _input).
	# Repeated click ticks require either:
	# - hold_enable + holding, or
	# - auto_click (later upgrade) regardless of holding.
	var holding_active := hold_enable and (_mouse_down or _space_down)
	var active := auto_click or holding_active
	if not active:
		_click_accum = 0.0
		return

	if auto_click_rate <= 0.0:
		return

	var period := 1.0 / auto_click_rate
	_click_accum += delta

	while _click_accum >= period:
		_click_accum -= period
		_handle_click(get_global_mouse_position())

func _input(event):
	# Listen for mouse button click/hold
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_mouse_down = true
			_click_accum = 0.0
			_handle_click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_mouse_down = false
	
	# Listen for space bar press/hold (works like mouse click)
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and not event.is_echo():
			if event.pressed:
				_space_down = true
			else:
				_space_down = false

			if event.pressed:
				# Fire immediately on press; continuous repeats are handled in _process.
				_click_accum = 0.0
			_handle_click(get_global_mouse_position())

func _handle_click(click_pos: Vector2) -> void:
	# Origin is the center of the screen as per requirements (Jerusalem).
	var screen_center := get_viewport_rect().size / 2
	var v := click_pos - screen_center
	if v.length() < minClickDist:
		return

	var click_angle := v.angle()

	# 1) If click hits an existing beam -> expand it (PRD behavior).
	var hit_cone: Node2D = _find_hit_cone(screen_center, click_pos, click_angle)
	if hit_cone != null:
		if hit_cone.has_method("apply_click_growth"):
			hit_cone.call("apply_click_growth", click_angle, clickImpact)
	else:
		# 2) Miss all beams -> spawn a new one centered at click angle.
		_spawn_cone_at_angle(click_angle, clickImpact, screen_center)

	# 3) Merge any beams that now touch/overlap.
	_merge_beams(click_angle)

func _find_hit_cone(screen_center: Vector2, click_pos: Vector2, click_angle: float) -> Node2D:
	var best: Node2D = null
	var best_score := INF

	for b in beams:
		if b == null or not is_instance_valid(b):
			continue
		if not b.has_method("contains_click"):
			continue

		if not b.call("contains_click", screen_center, click_pos):
			continue

		# If multiple beams contain the click (should be rare after merging),
		# pick the one whose center is closest to the click angle.
		var dir := float(b.get("direction_rad"))
		var a_u := _unwrap_near(click_angle, dir)
		var score := absf(a_u - dir)
		if score < best_score:
			best_score = score
			best = b

	return best

func _spawn_cone_at_angle(direction_angle: float, angle_deg: float, screen_center: Vector2) -> void:
	var cone := cone_scene.instantiate()
	cone.call("setup", direction_angle, coneRadius, angle_deg, lightDecay)
	(cone as Node2D).global_position = screen_center

	# Add to Beams layer + keep reference in memory
	beams_layer.add_child(cone)
	beams.append(cone)
	cone.tree_exited.connect(func() -> void:
		beams.erase(cone)
	)

func _merge_beams(ref_angle: float) -> void:
	# Merge on overlap/touch (PRD). We do it only after click actions
	# (shrinking cannot create new overlaps).
	var items: Array[Dictionary] = []

	for b in beams:
		if b == null or not is_instance_valid(b):
			continue
		if not b.has_method("setup"):
			continue

		var dir := float(b.get("direction_rad"))
		var spread := float(b.get("angle_spread_rad"))
		var c := _unwrap_near(dir, ref_angle)
		var h := spread * 0.5
		items.append({
			"cone": b,
			"min": c - h,
			"max": c + h,
		})

	if items.size() <= 1:
		return

	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["min"] < b["min"]
	)

	var i := 0
	while i < items.size():
		var base := items[i]
		var base_cone: Node2D = base["cone"]
		var base_min: float = base["min"]
		var base_max: float = base["max"]

		var absorbed: Array[Node2D] = []
		var j := i + 1
		while j < items.size():
			var next := items[j]
			var next_min: float = next["min"]
			if next_min > base_max + _MERGE_EPS_RAD:
				break

			var next_cone: Node2D = next["cone"]
			base_max = maxf(base_max, float(next["max"]))
			absorbed.append(next_cone)
			j += 1

		# Update survivor to the union interval.
		base_cone.set("direction_rad", wrapf((base_min + base_max) * 0.5, -PI, PI))
		base_cone.set("angle_spread_rad", base_max - base_min)
		if base_cone.has_method("queue_redraw"):
			base_cone.call("queue_redraw")

		# Free absorbed cones and remove them from the active list immediately.
		for dead in absorbed:
			if dead != null and is_instance_valid(dead):
				beams.erase(dead)
				dead.queue_free()

		i = j

func get_beams() -> Array[Node2D]:
	return beams
