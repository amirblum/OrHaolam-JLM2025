extends Node2D
class_name Cone

# Internal variables for the cone's appearance and life
var radius: float = 50
var angle_spread_rad: float = PI / 4.0
var direction_rad: float = 0.0
var duration: float = 2.0 # fallback decay rate (deg/sec) if no master is found

# When the cone "expires", it shrinks its angle over time instead of disappearing.
# `duration` is treated as a shrink rate in degrees per second.
const _MIN_ANGLE_RAD := 0.0001
const _ANGLE_EPS_RAD := 0.00001

static func unwrap_near(a: float, ref: float) -> float:
	# Return an equivalent angle to `a` that is closest to `ref`.
	# This makes comparisons robust when beams cross 0 / TAU.
	return ref + wrapf(a - ref, -PI, PI)

func contains_click(center: Vector2, click_pos: Vector2) -> bool:
	var v := click_pos - center
	if v.length() > radius:
		return false
	if angle_spread_rad <= 0.0:
		return false

	var a := v.angle()
	var a_u := unwrap_near(a, direction_rad)
	var half := angle_spread_rad * 0.5
	return absf(a_u - direction_rad) <= half + _ANGLE_EPS_RAD

func apply_click_growth(click_angle: float, click_impact_deg: float) -> void:
	# Expand the beam by exactly `click_impact_deg` total (PRD `clickImpact`),
	# split asymmetrically toward the nearer edge of the cone.
	if click_impact_deg <= 0.0:
		return

	var impact := deg_to_rad(click_impact_deg)
	var half := angle_spread_rad * 0.5
	var min_edge := direction_rad - half
	var max_edge := direction_rad + half

	var a_u := unwrap_near(click_angle, direction_rad)
	var denom := max_edge - min_edge
	var t := 0.5
	if denom > _MIN_ANGLE_RAD:
		# Normalized click position across [min_edge, max_edge].
		t = clampf((a_u - min_edge) / denom, 0.0, 1.0)

	# Split the added width exactly as PRD describes:
	# - Closer to min -> more expansion on min side (min decreases more)
	# - Closer to max -> more expansion on max side (max increases more)
	var expand_min := impact * (1.0 - t)
	var expand_max := impact * t

	var new_min := min_edge - expand_min
	var new_max := max_edge + expand_max

	direction_rad = wrapf((new_min + new_max) * 0.5, -PI, PI)
	angle_spread_rad = new_max - new_min
	queue_redraw()

# Initialize the cone properties from the player
func setup(p_direction: float, p_radius: float, p_angle_deg: float, p_duration: float) -> void:
	direction_rad = wrapf(p_direction, -PI, PI)
	radius = p_radius
	angle_spread_rad = deg_to_rad(p_angle_deg)
	duration = p_duration
	
	# Trigger a redraw immediately after setup
	queue_redraw()

func _get_master_light_decay_deg() -> float:
	# Cones are instanced under Player/Beams, so Player is the parent of our parent.
	# If that structure changes, we fall back to our local `duration`.
	var beams_parent := get_parent()
	if beams_parent == null:
		return duration
	var player := beams_parent.get_parent()
	if player == null:
		return duration
	if not is_instance_valid(player):
		return duration

	# `Player.gd` exposes `lightDecay` (deg/sec).
	var v: Variant = player.get("lightDecay")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return float(v)
	return duration

func _process(delta: float) -> void:
	# Shrink the cone's angle by master `lightDecay` (deg/sec).
	# This allows debug/upgrades to affect all existing cones.
	var decay_deg := _get_master_light_decay_deg()
	if decay_deg <= 0.0:
		return

	angle_spread_rad = maxf(0.0, angle_spread_rad - deg_to_rad(decay_deg) * delta)
	queue_redraw()

	if angle_spread_rad <= _MIN_ANGLE_RAD:
		queue_free()

func _draw() -> void:
	# Define points for the cone shape
	# We use a triangle-arc (pie slice) approach
	var points = PackedVector2Array()
	
	# 1. Start at the origin
	points.append(Vector2.ZERO)
	
	# 2. Calculate points along the arc
	var segments = 32 # Resolution of the arc curve
	var half_spread = angle_spread_rad / 2.0
	
	for i in range(segments + 1):
		# Calculate angle for this segment:
		# Start from (direction - half_spread) and sweep across the full angle_spread
		var current_angle = direction_rad - half_spread + (angle_spread_rad * i / segments)
		
		# Convert polar (angle, radius) to cartesian (x, y)
		var point = Vector2(cos(current_angle), sin(current_angle)) * radius
		points.append(point)
	
	# 3. Draw the filled shape
	# Pure white with some transparency for that "ghostly" cone look
	var color = Color(1.0, 1.0, 1.0, 1)
	draw_polygon(points, PackedColorArray([color]))
	
	## 4. Draw a solid white outline for better definition
	# draw_polyline(points, Color(1.0, 1.0, 1.0, 1.0), 2.0, true)
