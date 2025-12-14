extends Control

signal succeeded
signal failed

var buttons: Array = []
var next_number: int = 1
var total_numbers: int = 5
var game_timer: Timer
var time_limit: float = 0.0

# Visuals
var progress_bar: ProgressBar

func _ready():
	# Fill parent
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	game_timer = Timer.new()
	game_timer.one_shot = true
	game_timer.timeout.connect(_on_timeout)
	add_child(game_timer)
	
	# Create a reusable progress bar to attach to active button
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(50, 8)
	progress_bar.modulate = Color(1, 1, 0) # Yellow
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_bar)
	progress_bar.hide()

func _process(delta):
	if visible and game_timer.time_left > 0 and next_number <= buttons.size():
		# Update progress bar
		progress_bar.max_value = time_limit
		progress_bar.value = game_timer.time_left
		
		# Keep attached to current button
		var current_btn = buttons[next_number - 1]
		if is_instance_valid(current_btn):
			progress_bar.global_position = current_btn.global_position + Vector2(5, -15) # Above button
			progress_bar.show()

func start_game(duration: float = 2.0, center_pos: Vector2 = Vector2.ZERO):
	_clear_buttons()
	next_number = 1
	time_limit = duration
	visible = true
	
	if center_pos == Vector2.ZERO:
		center_pos = get_viewport_rect().size / 2.0
		
	# Random Positioning Logic
	# Area: "1/4 screen around player" -> Circle with Radius approx 300-400
	var spawn_radius = 250.0
	var btn_size = 60.0
	var positions = []
	
	for i in range(1, total_numbers + 1):
		var btn = Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(btn_size, btn_size)
		btn.modulate = Color(0.2, 0.8, 1.0)
		btn.pressed.connect(_on_btn_pressed.bind(i, btn))
		add_child(btn)
		buttons.append(btn)
		
		# Find non-overlapping position
		var valid_pos = center_pos
		var attempts = 0
		var found = false
		
		while attempts < 50 and not found:
			var angle = randf() * TAU
			var dist = randf_range(60, spawn_radius) # Minimum dist from player center
			var candidate = center_pos + Vector2(cos(angle), sin(angle)) * dist
			
			# Check overlap with existing
			var overlap = false
			for p in positions:
				if candidate.distance_to(p) < btn_size * 1.5: # 1.5x buffer
					overlap = true
					break
			
			# Check screen bounds (padding 60px)
			var vp = get_viewport_rect().size
			if candidate.x < 60 or candidate.x > vp.x - 60 or candidate.y < 60 or candidate.y > vp.y - 60:
				overlap = true
				
			if not overlap:
				valid_pos = candidate
				found = true
			
			attempts += 1
			
		positions.append(valid_pos)
		btn.position = valid_pos - (btn.custom_minimum_size / 2)
		
		# Animation
		btn.scale = Vector2.ZERO
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2.ONE, 0.3).set_delay(i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	game_timer.start(duration)

func _on_btn_pressed(number: int, btn: Button):
	if number == next_number:
		# Correct
		next_number += 1
		btn.modulate = Color.GREEN
		btn.disabled = true
		
		var t = create_tween()
		t.tween_property(btn, "modulate:a", 0.0, 0.2)
		t.tween_callback(btn.queue_free)
		
		# Add time bonus (0.5s)
		game_timer.start(game_timer.time_left + 0.5)
		
		if next_number > total_numbers:
			_win()
	else:
		_fail()

func _win():
	game_timer.stop()
	progress_bar.hide()
	_clear_buttons()
	succeeded.emit()
	visible = false

func _fail():
	game_timer.stop()
	progress_bar.hide()
	for b in buttons:
		if is_instance_valid(b):
			b.modulate = Color.RED
	
	await get_tree().create_timer(0.3).timeout
	_clear_buttons()
	failed.emit()
	visible = false

func _on_timeout():
	_fail()

func _clear_buttons():
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
