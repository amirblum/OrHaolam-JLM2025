extends Node2D

# Constants for cone behavior
@export var coneRadius: float = 1200.0
@export var clickImpact: float = 4.5 # Degrees, PRD `clickImpact`
@export var minClickDist: float = 2.0 # Minimum distance from center to register a click
@export var lightDecay: float = 5.0 # Deg/sec, PRD `lightDecay`
@export var hold_enable: bool = false # Upgrade: allows click-and-hold repeating ticks
@export var auto_click_rate: float = 12.0 # Clicks per second while holding / auto-clicking
@export var auto_click: bool = false # If true, auto-click even when not holding
@export var keep_beams_sorted_normalized: bool = true # Optional: keep beams globally merged + sorted (wrap-safe)

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

# Cached beam union for efficient light_state queries (many Persons/Cities per frame)
var _cached_beam_union: Array[Vector2] = [] # Array of Vector2(min,max) in [0,TAU)
var _cache_frame_id: int = -1

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
	if keep_beams_sorted_normalized:
		_normalize_and_sort_beams()
	
	# Invalidate cache so next light_state query sees updated beams.
	_invalidate_cache()

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

func _normalize_and_sort_beams() -> void:
	# Canonicalize beams globally (wrap-safe):
	# - represent beams as [min,max] in [0,TAU), splitting wrap intervals
	# - merge touching/overlapping into a minimal union
	# - combine endpoints into a single wrapped interval when union crosses 0
	# - apply the union back to cone nodes and delete extras
	var nodes: Array[Node2D] = []
	for b in beams:
		if b == null or not is_instance_valid(b):
			continue
		if not b.has_method("setup"):
			continue
		nodes.append(b)

	if nodes.size() <= 1:
		_sort_beams_by_direction()
		return

	var intervals: Array[Vector2] = []
	for b in nodes:
		var center0 := wrapf(float(b.get("direction_rad")), 0.0, TAU)
		var width := clampf(float(b.get("angle_spread_rad")), 0.0, TAU)
		if width <= 0.0:
			continue
		var half := width * 0.5
		var a_min := center0 - half
		var a_max := center0 + half

		# Split if this interval wraps around 0.
		if a_min < 0.0:
			intervals.append(Vector2(a_min + TAU, TAU))
			intervals.append(Vector2(0.0, a_max))
		elif a_max >= TAU:
			intervals.append(Vector2(a_min, TAU))
			intervals.append(Vector2(0.0, a_max - TAU))
		else:
			intervals.append(Vector2(a_min, a_max))

	if intervals.is_empty():
		# Nothing meaningful left; beams will self-delete as they shrink.
		_sort_beams_by_direction()
		return

	intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x
	)

	# Merge touching/overlapping intervals.
	var merged: Array[Vector2] = []
	var cur: Vector2 = intervals[0]
	for k in range(1, intervals.size()):
		var iv: Vector2 = intervals[k]
		if iv.x <= cur.y + _MERGE_EPS_RAD:
			cur.y = maxf(cur.y, iv.y)
		else:
			merged.append(cur)
			cur = iv
	merged.append(cur)

	# If union crosses 0, combine the end + start into one wrapped interval.
	if merged.size() >= 2 and merged[0].x <= _MERGE_EPS_RAD and merged[merged.size() - 1].y >= TAU - _MERGE_EPS_RAD:
		var first: Vector2 = merged[0] # [0, first.y]
		var last: Vector2 = merged[merged.size() - 1] # [last.x, TAU]
		merged.remove_at(merged.size() - 1)
		merged.remove_at(0)
		# Store a wrapped interval as Vector2(min,max) where min > max.
		merged.insert(0, Vector2(last.x, first.y))

	# Re-apply merged intervals to existing nodes (no new nodes needed).
	nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return wrapf(float(a.get("direction_rad")), 0.0, TAU) < wrapf(float(b.get("direction_rad")), 0.0, TAU)
	)

	var kept: Array[Node2D] = []
	var use_count: int = min(nodes.size(), merged.size())
	for idx in range(use_count):
		var n: Node2D = nodes[idx]
		var iv: Vector2 = merged[idx]
		var a_min: float = iv.x
		var a_max: float = iv.y

		var width := 0.0
		if a_min <= a_max:
			width = a_max - a_min
		else:
			# wrapped interval
			width = (TAU - a_min) + a_max

		var center0 := wrapf(a_min + width * 0.5, 0.0, TAU)
		n.set("direction_rad", wrapf(center0, -PI, PI))
		n.set("angle_spread_rad", width)
		if n.has_method("queue_redraw"):
			n.call("queue_redraw")
		kept.append(n)

	# Delete any leftover nodes (they represent redundant overlaps).
	for idx in range(use_count, nodes.size()):
		var dead := nodes[idx]
		if dead != null and is_instance_valid(dead):
			beams.erase(dead)
			dead.queue_free()

	# Replace the beams list with the kept, sorted set.
	beams = kept
	_sort_beams_by_direction()

func _sort_beams_by_direction() -> void:
	beams.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return float(a.get("direction_rad")) < float(b.get("direction_rad"))
	)

func get_beams() -> Array[Node2D]:
	return beams

# ============================================================================
# Light state query API (for Cities/Persons)
# ============================================================================

func light_state(point: Vector2, radius: float) -> float:
	# Returns 0.0 (fully dark), 0.5 (partial light), 1.0 (fully lit).
	# Uses cached beam union for efficiency (many entities query per frame).
	var center := get_viewport_rect().size * 0.5
	
	if radius <= 0.0:
		# Treat as point query (simplified).
		var theta := (point - center).angle()
		_ensure_cache_fresh()
		for iv in _cached_beam_union:
			var theta_norm := wrapf(theta, 0.0, TAU)
			if _interval_contains_angle(iv, theta_norm):
				return 1.0
		return 0.0
	
	var span := _circle_angle_span(center, point, radius)
	var d: float = span["d"]
	var a_min: float = span["min_norm"]
	var a_max: float = span["max_norm"]
	var wraps: bool = span["wraps"]
	
	# Radial early-out: whole circle is outside beam reach.
	if (d - radius) >= coneRadius:
		return 0.0
	
	_ensure_cache_fresh()
	
	if _cached_beam_union.is_empty():
		return 0.0
	
	# 1) Check for any overlap.
	var any_overlap := false
	if wraps:
		# Entity wraps 0: check both sides.
		for iv in _cached_beam_union:
			if _intervals_overlap_or_touch(iv, Vector2(a_min, TAU)) or _intervals_overlap_or_touch(iv, Vector2(0.0, a_max)):
				any_overlap = true
				break
	else:
		for iv in _cached_beam_union:
			if _intervals_overlap_or_touch(iv, Vector2(a_min, a_max)):
				any_overlap = true
				break
	
	if not any_overlap:
		return 0.0
	
	# 2) Full coverage requires circle fully inside beam radius.
	if (d + radius) > coneRadius:
		return 0.5
	
	# 3) Check if union of beams fully covers entity angular span.
	if wraps:
		# Entity wraps: both [a_min, TAU] and [0, a_max] must be covered.
		var covered_high := _span_fully_covered(a_min, TAU)
		var covered_low := _span_fully_covered(0.0, a_max)
		if covered_high and covered_low:
			return 1.0
	else:
		if _span_fully_covered(a_min, a_max):
			return 1.0
	
	return 0.5

func _invalidate_cache() -> void:
	_cache_frame_id = -1

func _ensure_cache_fresh() -> void:
	var current_frame := Engine.get_process_frames()
	if _cache_frame_id == current_frame:
		return
	_cache_frame_id = current_frame
	_rebuild_beam_union_cache()

func _rebuild_beam_union_cache() -> void:
	# Build a minimal, merged union of beam intervals in [0,TAU) for fast queries.
	var intervals: Array[Vector2] = []
	for b in beams:
		if b == null or not is_instance_valid(b):
			continue
		var center0 := wrapf(float(b.get("direction_rad")), 0.0, TAU)
		var width := clampf(float(b.get("angle_spread_rad")), 0.0, TAU)
		if width <= 0.0:
			continue
		var half := width * 0.5
		var a_min := center0 - half
		var a_max := center0 + half
		
		# Split if wraps.
		if a_min < 0.0:
			intervals.append(Vector2(a_min + TAU, TAU))
			intervals.append(Vector2(0.0, a_max))
		elif a_max >= TAU:
			intervals.append(Vector2(a_min, TAU))
			intervals.append(Vector2(0.0, a_max - TAU))
		else:
			intervals.append(Vector2(a_min, a_max))
	
	if intervals.is_empty():
		_cached_beam_union = []
		return
	
	intervals.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x
	)
	
	# Merge touching/overlapping.
	var merged: Array[Vector2] = []
	var cur: Vector2 = intervals[0]
	for k in range(1, intervals.size()):
		var iv: Vector2 = intervals[k]
		if iv.x <= cur.y + _MERGE_EPS_RAD:
			cur.y = maxf(cur.y, iv.y)
		else:
			merged.append(cur)
			cur = iv
	merged.append(cur)
	
	# If union crosses 0, combine end + start into one wrapped interval.
	if merged.size() >= 2 and merged[0].x <= _MERGE_EPS_RAD and merged[merged.size() - 1].y >= TAU - _MERGE_EPS_RAD:
		var first: Vector2 = merged[0]
		var last: Vector2 = merged[merged.size() - 1]
		merged.remove_at(merged.size() - 1)
		merged.remove_at(0)
		merged.insert(0, Vector2(last.x, first.y))
	
	_cached_beam_union = merged

func _circle_angle_span(center: Vector2, point: Vector2, r: float) -> Dictionary:
	# Returns entity circle's angular span from center.
	var p := point - center
	var d := p.length()
	var theta := p.angle()
	var theta_norm := wrapf(theta, 0.0, TAU)
	
	# Circle contains the center -> full angular span (wraps).
	if d <= r:
		return {
			"d": d,
			"theta": theta,
			"min_norm": 0.0,
			"max_norm": TAU,
			"wraps": true
		}
	
	var alpha := asin(clampf(r / d, 0.0, 1.0))
	var a_min := wrapf(theta_norm - alpha, 0.0, TAU)
	var a_max := wrapf(theta_norm + alpha, 0.0, TAU)
	var wraps := a_min > a_max
	
	return {
		"d": d,
		"theta": theta,
		"min_norm": a_min,
		"max_norm": a_max,
		"wraps": wraps
	}

func _intervals_overlap_or_touch(a: Vector2, b: Vector2) -> bool:
	# Both intervals in [0,TAU), neither wraps (caller splits wrapped intervals).
	return a.x <= b.y + _MERGE_EPS_RAD and b.x <= a.y + _MERGE_EPS_RAD

func _interval_contains_angle(iv: Vector2, angle: float) -> bool:
	# iv is in [0,TAU); angle is in [0,TAU).
	# Handle wrapped interval (min > max).
	if iv.x <= iv.y:
		return angle >= iv.x and angle <= iv.y
	else:
		# wrapped: [min, TAU) or [0, max]
		return angle >= iv.x or angle <= iv.y

func _span_fully_covered(target_min: float, target_max: float) -> bool:
	# Check if union of cached intervals fully covers [target_min, target_max].
	var covered_until := target_min
	for iv in _cached_beam_union:
		if iv.y < covered_until:
			continue
		if iv.x > covered_until + _MERGE_EPS_RAD:
			return false # gap
		covered_until = maxf(covered_until, iv.y)
		if covered_until >= target_max - _MERGE_EPS_RAD:
			return true
	return false
