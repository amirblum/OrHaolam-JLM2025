extends Node2D

# Constants for cone behavior
@export var coneRadius: float = 1200.0
@export var clickImpact: float = 4.5 # Degrees, PRD `clickImpact`
@export var minClickDist: float = 2.0 # Minimum distance from center to register a click
@export var lightDecay: float = 5.0 # Deg/sec, PRD `lightDecay`
@export var hold_enable: bool = false # Upgrade: allows click-and-hold repeating ticks
@export var auto_click_rate: float = 12.0 # Clicks per second while holding / auto-clicking
@export var auto_click: bool = false # If true, auto-click even when not holding
@export var player_radius: float = 50.0 # Distance at which Persons steal light from Jerusalem, PRD `player_radius`
@export var lightBank: float = 100.0 # Light currency, PRD `lightBank`
@export var light_bank_radius: float = 80.0 # Radius of the light bank visual indicator
@export var rim: float = 10.0 # Rim width for the light bank visual indicator
@export var fill_rate: float = 0.5 # fill rate for the light tank
@export var light_cost: float = 10; # cost to spawn a person
const _MERGE_EPS_RAD := 0.00001

static func _unwrap_near(a: float, ref: float) -> float:
	# Return an equivalent angle to `a` that is closest to `ref`.
	return ref + wrapf(a - ref, -PI, PI)

# Preload the cone scene
@onready var cone_scene = preload("res://scenes/cone/Cone.tscn")

# Layer/container for all active beam instances (cones)
@onready var beams_layer: Node2D = get_node_or_null("Beams")

# Customizable position marker for Jerusalem center (can be placed anywhere in the scene)
@export var jerusalem_center_marker: NodePath = NodePath("")

# Accessible memory: keep references to currently-active beam instances.
var beams: Array[Node2D] = []

# Reference to the light bank visual node
var light_bank_node: Node2D = null

var _mouse_down := false
var _space_down := false
var _click_accum := 0.0
var time_accum: = 0.0

# Helper function to get the Jerusalem center position
func get_jerusalem_center() -> Vector2:
	# First, try to use the custom position marker if set
	if jerusalem_center_marker != NodePath(""):
		var marker_node = get_node_or_null(jerusalem_center_marker)
		if marker_node != null and is_instance_valid(marker_node) and marker_node is Node2D:
			return (marker_node as Node2D).global_position
	
	# Fallback to viewport center if no marker is set
	return get_viewport_rect().size / 2

func _ready() -> void:
	# Create the light bank visual indicator
	light_bank_node = Node2D.new()
	light_bank_node.name = "lightBank"
	add_child(light_bank_node)
	
	# Ensure there is always a Beams container, even if the scene wasn't set up yet.
	if beams_layer == null:
		beams_layer = Node2D.new()
		beams_layer.name = "Beams"
		add_child(beams_layer)
	
	await get_tree().process_frame
	
	var jerusalem_center := get_jerusalem_center()
	light_bank_node.global_position = jerusalem_center
	
	# Set up the light bank drawing
	light_bank_node.draw.connect(func():
		# 1. Draw outer white rim circle
		#light_bank_node.draw_circle(Vector2.ZERO, light_bank_radius + rim, Color(0.98, 0.655, 0.478, 1.0))
		
		# 2. Draw the base grey inner circle (empty state)
		light_bank_node.draw_circle(Vector2.ZERO, light_bank_radius-0.1, Color(0.149, 0.133, 0.384, 1.0))
		
		# 3. Calculate fill height based on lightBank percentage
		var fill_percent := clampf(lightBank / 100.0, 0.0, 1.0)
		
		# 4. Draw the white fill polygon representing the filled portion
		var points := _get_circle_fill_polygon(light_bank_radius, fill_percent)
		if points.size() > 0:
			light_bank_node.draw_colored_polygon(points, Color(0.957, 1.0, 1.0, 1.0))
	)
	light_bank_node.queue_redraw()
	
	queue_redraw()

#func _draw() -> void:
	## Draw a circle at the screen center (where beams originate) with radius equal to player_radius
	#var screen_center := get_viewport_rect().size / 2
	#var local_center := to_local(screen_center)
	#draw_circle(local_center, player_radius, Color(1.0, 0.0, 1.0, 1.0))

func _get_circle_fill_polygon(radius: float, fill_percent: float) -> PackedVector2Array:
	"""Generate polygon points that fill a circle from bottom to given percentage"""
	if fill_percent <= 0.0:
		return PackedVector2Array()
	
	var points := PackedVector2Array()
	var segments := 32
	
	# Calculate the Y position of the fill line (0 is center)
	# Bottom of circle is at Y = +radius, top is at Y = -radius
	var fill_y := radius - (radius * 2 * fill_percent)
	
	if fill_percent >= 1.0:
		# Fully filled - just return a circle approximation
		for i in range(segments):
			var angle := (float(i) / segments) * TAU
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
		return points
	
	# Calculate where the fill line intersects the circle
	# Circle equation: x² + y² = r²
	# Build the polygon:
	# Start from left intersection point, go down along arc to bottom,
	# continue along arc to right intersection point, then line back
	var start_angle := asin(fill_y / radius) # Left intersection angle
	var end_angle := PI - start_angle # Right intersection angle
	
	# Add points along the arc from left to right (going through bottom)
	for i in range(segments + 1):
		var t := float(i) / segments
		var angle := start_angle + (end_angle - start_angle) * t
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	
	return points

func _process(delta: float) -> void:
	
	time_accum += delta
	# Fill the light tank over time based on fill_rate
	if fill_rate > 0.0 and lightBank < 100.0:
		var old_bank := lightBank
		lightBank = minf(100.0, lightBank + fill_rate * delta)
		# Redraw if the value changed
		if lightBank != old_bank and light_bank_node:
			light_bank_node.queue_redraw()
	
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
				_space_down = false
			else:
				_space_down = false

			if event.pressed:
				# Fire immediately on press; continuous repeats are handled in _process.
				_click_accum = 0.0
			#_handle_click(get_global_mouse_position())

func _handle_click(click_pos: Vector2) -> void:
	# Check if there's enough light in the bank to perform the click
	if lightBank < light_cost:
		return
	
	# Origin is the center of the screen as per requirements (Jerusalem).
	var jerusalem_center := get_jerusalem_center()
	var v := click_pos - jerusalem_center
	if v.length() < minClickDist:
		return
	
	# Deduct light cost from the light bank
	var old_bank := lightBank
	lightBank = maxf(0.0, lightBank - light_cost)
	# Trigger redraw if the value changed
	if lightBank != old_bank and light_bank_node:
		light_bank_node.queue_redraw()

	var click_angle := v.angle()

	# 1) If click hits an existing beam -> expand it (PRD behavior).
	var hit_cone: Node2D = _find_hit_cone(jerusalem_center, click_pos, click_angle)
	if hit_cone != null:
		if hit_cone.has_method("apply_click_growth"):
			hit_cone.call("apply_click_growth", click_angle, clickImpact)
	else:
		# 2) Miss all beams -> spawn a new one centered at click angle.
		_spawn_cone_at_angle(click_angle, clickImpact, jerusalem_center)

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

func decrease_light_bank(amount: float) -> void:
	lightBank = maxf(0.0, lightBank - amount)
	# Trigger redraw of the light bank indicator
	if light_bank_node:
		light_bank_node.queue_redraw()

func light_state(point: Vector2, radius: float) -> float:
	"""
	Determines the light state of a circular region.
	
	Args:
		point: The center point of the circle in global coordinates
		radius: The radius of the circle in pixels
	
	Returns:
		0.0 - None of the sample angles are in any beam
		0.5 - Some angles are in beams OR angles are in different beams
		1.0 - All three angles are in the same beam
	"""
	# Get the Jerusalem center origin
	var jerusalem_center := get_jerusalem_center()
	
	# Calculate vector from Jerusalem center to the point
	var v := point - jerusalem_center
	var distance := v.length()
	
	# Calculate the three angles
	var center_angle := v.angle()
	
	# Calculate angular offset for the circle edges
	# tan(theta) = radius / distance, so theta = atan(radius / distance)
	var angular_offset := atan2(radius, distance) if distance > 0.0 else 0.0
	
	var min_angle := center_angle - angular_offset
	var max_angle := center_angle + angular_offset
	
	# Find which beam (if any) contains each angle
	var center_beam := _find_beam_containing_angle(center_angle)
	var min_beam := _find_beam_containing_angle(min_angle)
	var max_beam := _find_beam_containing_angle(max_angle)
	
	# Count how many angles are in beams
	var in_beam_count := 0
	if center_beam != null:
		in_beam_count += 1
	if min_beam != null:
		in_beam_count += 1
	if max_beam != null:
		in_beam_count += 1
	
	# Case 1: None in any beam
	if in_beam_count == 0:
		return 0.0
	
	# Case 2: All three in the same beam
	if in_beam_count == 3 and center_beam == min_beam and min_beam == max_beam:
		return 1.0
	
	# Case 3: Some in beams or in different beams
	return 0.5

func _find_beam_containing_angle(angle: float) -> Node2D:
	"""
	Finds the beam that contains the given angle.
	
	Args:
		angle: The angle to check (in radians)
	
	Returns:
		The beam Node2D that contains this angle, or null if none
	"""
	for b in beams:
		if b == null or not is_instance_valid(b):
			continue
		
		var dir := float(b.get("direction_rad"))
		var spread := float(b.get("angle_spread_rad"))
		var half_spread := spread * 0.5
		
		# Unwrap the test angle near the beam's direction to handle wraparound
		var angle_unwrapped := _unwrap_near(angle, dir)
		
		# Check if angle is within the beam's range
		if angle_unwrapped >= (dir - half_spread) and angle_unwrapped <= (dir + half_spread):
			return b
	
	return null
