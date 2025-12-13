extends Node2D

# Config
const PLAYER_HP_MAX = 100
const ENEMY_HP_MAX = 100
const BASE_DAMAGE = 15
const DIFFICULTY = 2 # 1-3

# State
var player_hp = PLAYER_HP_MAX
var enemy_hp = ENEMY_HP_MAX
var current_turn = "Player"
var swipe_active = false
var swipe_start_pos = Vector2()
var swipe_end_pos = Vector2()
var is_dragging = false
var swipe_time_left = 0.0
var swipe_duration = 0.0

# Visuals
var player_node
var enemy_node
var ui_layer
var hp_label_player
var hp_label_enemy
var status_label

# Swipe Visuals
var swipe_container
var start_circle
var end_circle
var swipe_line
var approach_circle
var drag_line

func _ready():
	_setup_environment()
	_setup_visuals()
	_update_ui()
	_start_battle()

func _setup_environment():
	# World Environment for Glow
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)

func _setup_visuals():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1) # Dark Blue-Black
	bg.size = get_viewport_rect().size
	add_child(bg)

	# Floor (Neon Line)
	var floor_line = Line2D.new()
	floor_line.default_color = Color(0.0, 1.0, 1.0, 0.5) # Cyan
	floor_line.width = 4
	floor_line.add_point(Vector2(100, 450))
	floor_line.add_point(Vector2(1052, 450))
	add_child(floor_line)

	# Player Stick Figure
	player_node = _create_stick_figure(Color(0.2, 0.8, 1.0), true)
	player_node.position = Vector2(250, 450)
	add_child(player_node)
	_add_hat(player_node, "TopHat", Color(1.0, 0.8, 0.2)) # Gold Top Hat
	_animate_idle(player_node)

	# Enemy Stick Figure
	enemy_node = _create_stick_figure(Color(1.0, 0.2, 0.4), false)
	enemy_node.position = Vector2(850, 450)
	enemy_node.scale.x = -1 # Face left
	add_child(enemy_node)
	_add_hat(enemy_node, "Cap", Color(0.2, 1.0, 0.4)) # Green Cap
	_animate_idle(enemy_node)

	# UI Layer
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
# ... (rest of _setup_visuals) ...

# --- Visual Helpers ---

func _add_hat(parent_node, type, color):
	# Head is the second child (index 1) based on _create_stick_figure
	var head = parent_node.get_child(1)
	
	var hat = Node2D.new()
	# Hat sits on top of head (radius ~15)
	hat.position = Vector2(0, -15) 
	head.add_child(hat)
	
	if type == "TopHat":
		var line = Line2D.new()
		line.default_color = color
		line.width = 4
		# Brim
		line.add_point(Vector2(-20, 0))
		line.add_point(Vector2(20, 0))
		# Top
		line.add_point(Vector2(12, 0))
		line.add_point(Vector2(12, -30))
		line.add_point(Vector2(-12, -30))
		line.add_point(Vector2(-12, 0))
		hat.add_child(line)
		
	elif type == "Cap":
		var line = Line2D.new()
		line.default_color = color
		line.width = 4
		# Dome
		for i in range(16):
			var angle = PI + (i * PI / 15.0) # Semicircle
			line.add_point(Vector2(cos(angle), sin(angle)*0.8) * 16)
		# Bill
		line.add_point(Vector2(16, 0))
		line.add_point(Vector2(28, 5))
		hat.add_child(line)

func _create_stick_figure(color, is_player):
	var node = Node2D.new()
	
	# Body
	var body = Line2D.new()
	body.width = 6
	body.default_color = color
	body.add_point(Vector2(0, 0)) # Hip
	body.add_point(Vector2(0, -60)) # Shoulder
	node.add_child(body)
	
	# Head
	var head = Line2D.new()
	head.width = 6
	head.default_color = color
	_create_circle_points(head, 15, 16)
	head.position = Vector2(0, -80)
	node.add_child(head)
	
	# Arms (Simple V)
	var arms = Line2D.new()
	arms.width = 6
	arms.default_color = color
	arms.add_point(Vector2(-20, -30)) # Hand L
	arms.add_point(Vector2(0, -60))   # Shoulder
	arms.add_point(Vector2(20, -30))  # Hand R
	node.add_child(arms)
	
	# Legs
	var legs = Line2D.new()
	legs.width = 6
	legs.default_color = color
	legs.add_point(Vector2(-15, 0)) # Foot L (offset by animation)
	legs.add_point(Vector2(0, 0))   # Hip
	legs.add_point(Vector2(15, 0))  # Foot R
	node.add_child(legs)
	
	return node

func _create_circle_points(line_node, radius, segments):
	line_node.clear_points()
	for i in range(segments + 1):
		var angle = i * TAU / segments
		line_node.add_point(Vector2(cos(angle), sin(angle)) * radius)

func _animate_idle(node):
	var tween = create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(1.05, 0.95), 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2(0.95, 1.05), 1.0).set_trans(Tween.TRANS_SINE)
	if node == enemy_node:
		# Keep X flipped
		tween.stop()
		tween = create_tween().set_loops()
		tween.tween_property(node, "scale", Vector2(-1.05, 0.95), 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "scale", Vector2(-0.95, 1.05), 1.0).set_trans(Tween.TRANS_SINE)


# --- Game Logic ---

func _process(delta):
	if swipe_active:
		swipe_time_left -= delta
		
		# Animate Approach Circle
		if swipe_duration > 0:
			var ratio = swipe_time_left / swipe_duration
			# Shrinks from 2.5x to 1.0x
			var s = 1.0 + (ratio * 1.5)
			approach_circle.scale = Vector2(s, s)
		
		if swipe_time_left <= 0:
			_fail_swipe("TOO SLOW!")
	
	if is_dragging:
		# Update drag trail
		drag_line.add_point(swipe_container.get_local_mouse_position())
		if drag_line.get_point_count() > 10:
			drag_line.remove_point(0)

func _input(event):
	if not swipe_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Simple Hitbox for Start Circle
				var d = event.position.distance_to(start_circle.position)
				if d < 40:
					is_dragging = true
					drag_line.clear_points()
					drag_line.add_point(event.position)
					start_circle.default_color = Color.YELLOW
			else:
				if is_dragging:
					is_dragging = false
					var d = event.position.distance_to(end_circle.position)
					if d < 40:
						_succeed_swipe()
					else:
						_fail_swipe("MISSED!")

func _start_battle():
	player_hp = PLAYER_HP_MAX
	enemy_hp = ENEMY_HP_MAX
	_update_ui()
	_start_player_turn()

func _start_player_turn():
	current_turn = "Player"
	_show_popup("PLAYER TURN")
	_generate_swipe()

func _generate_swipe():
	swipe_active = true
	is_dragging = false
	swipe_container.visible = true
	drag_line.clear_points()
	
	var window = 2.0 - (DIFFICULTY * 0.4)
	swipe_duration = window
	swipe_time_left = window
	
	var center = enemy_node.position + Vector2(0, -60) # Center on enemy body
	var offset_range = 100 + (DIFFICULTY * 30)
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * offset_range
	
	swipe_start_pos = center - offset
	swipe_end_pos = center + offset
	
	start_circle.position = swipe_start_pos
	end_circle.position = swipe_end_pos
	approach_circle.position = swipe_start_pos
	approach_circle.scale = Vector2(2.5, 2.5) # Reset scale
	
	start_circle.default_color = Color(0.4, 1.0, 0.4) # Reset color
	
	swipe_line.clear_points()
	swipe_line.add_point(swipe_start_pos)
	swipe_line.add_point(swipe_end_pos)

func _succeed_swipe():
	swipe_active = false
	swipe_container.visible = false
	
	var damage = BASE_DAMAGE
	var note = "GOOD!"
	
	if swipe_time_left > swipe_duration * 0.5:
		damage *= 2
		note = "PERFECT!"
		_shake_screen(5.0)
	
	_animate_attack(player_node, enemy_node)
	await get_tree().create_timer(0.2).timeout
	
	enemy_hp = max(0, enemy_hp - damage)
	_pop_damage(damage, enemy_node.position, note)
	_update_ui()
	
	if enemy_hp <= 0:
		_check_game_over()
	else:
		await get_tree().create_timer(1.0).timeout
		_start_enemy_turn()

func _fail_swipe(reason):
	swipe_active = false
	swipe_container.visible = false
	_pop_damage(0, enemy_node.position, reason)
	
	await get_tree().create_timer(1.0).timeout
	_start_enemy_turn()

func _start_enemy_turn():
	current_turn = "Enemy"
	
	await get_tree().create_timer(1.0).timeout
	
	# Attack Anim
	_animate_attack(enemy_node, player_node)
	await get_tree().create_timer(0.2).timeout
	
	var roll = randf()
	var damage = BASE_DAMAGE
	var note = "HIT"
	
	if roll > 0.8:
		damage *= 2
		note = "CRITICAL"
		_shake_screen(10.0)
	elif roll < 0.2:
		damage = 0
		note = "MISS"

	player_hp = max(0, player_hp - damage)
	_pop_damage(damage, player_node.position, note)
	_update_ui()
	_check_game_over()
	
	if player_hp > 0:
		await get_tree().create_timer(1.0).timeout
		_start_player_turn()

func _update_ui():
	hp_label_player.text = "HP: %d" % player_hp
	hp_label_enemy.text = "HP: %d" % enemy_hp

func _pop_damage(amount, pos, text=""):
	var label = Label.new()
	label.text = text + " " + str(amount)
	label.modulate = Color(1.0, 1.0, 0.2)
	label.position = pos + Vector2(0, -100)
	label.scale = Vector2(2, 2)
	ui_layer.add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position", pos + Vector2(0, -200), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _show_popup(text):
	status_label.text = text
	status_label.scale = Vector2(0, 0)
	var tween = create_tween()
	tween.tween_property(status_label, "scale", Vector2(1.5, 1.5), 0.5).set_trans(Tween.TRANS_ELASTIC)

func _animate_attack(attacker, target):
	var start = attacker.position
	var end = target.position - (target.position - attacker.position).normalized() * 100
	
	var tween = create_tween()
	tween.tween_property(attacker, "position", end, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "position", start, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _shake_screen(amount):
	var tween = create_tween()
	var org = Vector2(0,0)
	for i in range(10):
		var off = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(self, "position", off, 0.05)
	tween.tween_property(self, "position", org, 0.05)

func _check_game_over():
	if player_hp <= 0:
		_show_popup("DEFEAT")
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()
	elif enemy_hp <= 0:
		_show_popup("VICTORY")
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()
