extends Node2D

class_name SwipeInput

signal swipe_started(pos)
signal swipe_ended(start, end)
signal swipe_updated(current_pos)

# Config
const TRAIL_LENGTH = 10

# State
var is_dragging = false
var drag_start = Vector2()
var drag_active = false
var input_enabled = false

# Components
var drag_trail: Line2D
var guide_line: Line2D
var guide_arrow: Line2D
var target_circle: Line2D
var timer_line: Line2D
var sandevistan_timer_ring: Line2D

func _ready():
	_setup_visuals()

func _input(event):
	if not input_enabled: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.position)
			else:
				_end_drag(event.position)

func _process(delta):
	if is_dragging:
		var current_pos = get_local_mouse_position()
		
		# Update Trail
		drag_trail.add_point(current_pos)
		if drag_trail.get_point_count() > TRAIL_LENGTH:
			drag_trail.remove_point(0)
			
		swipe_updated.emit(current_pos)

func set_active(active: bool):
	input_enabled = active
	if not active:
		is_dragging = false
		drag_trail.clear_points()
		guide_line.visible = false
		guide_arrow.visible = false
		timer_line.visible = false
		target_circle.visible = false
		sandevistan_timer_ring.visible = false

func show_guide(start: Vector2, end: Vector2):
	guide_line.visible = true
	guide_arrow.visible = true
	
	guide_line.clear_points()
	guide_line.add_point(start)
	guide_line.add_point(end)
	
	# Arrow tip calculation
	var vector = end - start

	
	guide_arrow.clear_points()
	guide_arrow.add_point(end - (vector.normalized() * 20) + (vector.orthogonal().normalized() * 10))
	guide_arrow.add_point(end)
	guide_arrow.add_point(end - (vector.normalized() * 20) - (vector.orthogonal().normalized() * 10))

func show_target_circle(pos: Vector2):
	guide_line.visible = false
	guide_arrow.visible = false
	target_circle.visible = true
	target_circle.position = pos

func update_timer(start: Vector2, end: Vector2, percent: float):
	if percent <= 0:
		timer_line.visible = false
		return
		
	timer_line.visible = true
	timer_line.clear_points()
	
	# Offset logic
	var dir = (end - start).normalized()
	var perp = Vector2(-dir.y, dir.x) * 40 # Offset by 40 pixels
	
	var offset_start = start + perp
	var offset_end = end + perp
	
	# Lerp end point based on percent
	var current_end = offset_start.lerp(offset_end, percent)
	
	timer_line.add_point(offset_start)
	timer_line.add_point(current_end)

func hide_timer():
	timer_line.visible = false

func update_sandevistan_timer(center: Vector2, percent: float):
	sandevistan_timer_ring.visible = true
	sandevistan_timer_ring.clear_points()
	
	var radius = 50 # Slightly larger than target
	var points = 32
	var end_angle = TAU * percent
	
	for i in range(points + 1):
		var angle = (i / float(points)) * TAU
		if angle > end_angle: break
		
		# Start from top (-PI/2) and go clockwise
		var draw_angle = angle - PI / 2
		sandevistan_timer_ring.add_point(center + Vector2(cos(draw_angle), sin(draw_angle)) * radius)

func hide_all_timers():
	timer_line.visible = false
	sandevistan_timer_ring.visible = false

func _start_drag(pos):
	is_dragging = true
	drag_start = pos
	drag_trail.clear_points()
	drag_trail.add_point(drag_start)
	swipe_started.emit(pos)

func _end_drag(pos):
	if is_dragging:
		is_dragging = false
		swipe_ended.emit(drag_start, pos)

func _setup_visuals():
	# Trail
	drag_trail = Line2D.new()
	drag_trail.width = 8
	drag_trail.default_color = Color.CYAN
	add_child(drag_trail)
	
	# Guide Line
	guide_line = Line2D.new()
	guide_line.width = 40
	guide_line.default_color = Color(1, 1, 1, 0.1)
	guide_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	guide_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	guide_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	guide_line.visible = false
	add_child(guide_line)
	
	# Guide Arrow
	guide_arrow = Line2D.new()
	guide_arrow.width = 10
	guide_arrow.default_color = Color(0.5, 1.0, 0.5, 0.8)
	guide_arrow.visible = false
	add_child(guide_arrow)
	
	# Target Circle
	target_circle = Line2D.new()
	_create_circle(target_circle, 40)
	target_circle.default_color = Color(1, 0.2, 0.2, 0.8)
	target_circle.width = 4
	target_circle.visible = false
	add_child(target_circle)
	
	# Timer Line
	timer_line = Line2D.new()
	timer_line.width = 15
	timer_line.default_color = Color(0.6, 0.6, 0.6, 0.4) # Gray, transparent
	timer_line.visible = false
	add_child(timer_line)
	
	# Sandevistan Ring Timer
	sandevistan_timer_ring = Line2D.new()
	sandevistan_timer_ring.width = 4
	sandevistan_timer_ring.default_color = Color(1.0, 0.8, 0.0, 0.8) # Gold
	sandevistan_timer_ring.visible = false
	add_child(sandevistan_timer_ring)

func _create_circle(line, radius):
	for i in range(17):
		var angle = i * TAU / 16.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)

func animate_target_hit():
	var tw = create_tween()
	tw.tween_property(target_circle, "scale", Vector2(1.2, 1.2), 0.05)
	tw.tween_property(target_circle, "scale", Vector2(1.0, 1.0), 0.05)
