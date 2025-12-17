extends Node2D

# Internal variables for the cone's appearance and life
var radius: float = 200.0
var angle_spread_rad: float = PI / 4.0
var direction_rad: float = 0.0
var duration: float = 2.0
var timer: float = 0.0

# Initialize the cone properties from the player
func setup(p_direction: float, p_radius: float, p_angle_deg: float, p_duration: float) -> void:
	direction_rad = p_direction
	radius = p_radius
	angle_spread_rad = deg_to_rad(p_angle_deg)
	duration = p_duration
	
	# Trigger a redraw immediately after setup
	queue_redraw()

func _process(delta: float) -> void:
	timer += delta
	
	# Once the duration is exceeded, remove the cone
	if timer >= duration:
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
	var color = Color(1.0, 1.0, 1.0, 0.5)
	draw_polygon(points, PackedColorArray([color]))
	
	# 4. Draw a solid white outline for better definition
	draw_polyline(points, Color(1.0, 1.0, 1.0, 1.0), 2.0, true)
