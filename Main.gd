extends Node2D

# Config
const PLAYER_HP_MAX = 100
const ENEMY_HP_MAX = 100
const BASE_DAMAGE = 10
const MAX_COMBO = 5
const SANDEVISTAN_DURATION = 5.0 # Real time seconds (affected by timescale)

# State
var player_hp = PLAYER_HP_MAX
var enemy_hp = ENEMY_HP_MAX
var energy = 0 # 0-100
var current_turn = "Player"

# Combat State
var combo_count = 0
var is_sandevistan = false
var swipe_active = false
var swipe_start_pos = Vector2()
var swipe_end_pos = Vector2()
var swipe_time_left = 0.0
var swipe_duration = 0.0
var required_angle = 0.0 # Radians

# Input State
var is_dragging = false
var drag_start = Vector2()

# Visuals
var player_node
var enemy_node
var player_sword
var enemy_sword
var ui_layer
var hp_label_player
var hp_label_enemy
var status_label
var energy_bar

# Overlay Visuals
var swipe_overlay
var guide_arrow
var guide_line
var drag_trail
var slash_line

func _ready():
	randomize()
	_setup_environment()
	_setup_visuals()
	_update_ui()
	_start_battle()

func _setup_environment():
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.2
	env.glow_bloom = 0.3
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)

func _setup_visuals():
	# BG
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.size = get_viewport_rect().size
	add_child(bg)
	
	# Floor
	var floor_line = Line2D.new()
	floor_line.default_color = Color(0.0, 1.0, 1.0, 0.5)
	floor_line.width = 4
	floor_line.add_point(Vector2(50, 500))
	floor_line.add_point(Vector2(1100, 500))
	add_child(floor_line)

	# Characters
	player_node = _create_stick_figure(Color(0.2, 0.8, 1.0), true)
	player_node.position = Vector2(250, 480)
	add_child(player_node)
	_add_hat(player_node, "TopHat", Color(1.0, 0.8, 0.2))
	player_sword = _add_sword(player_node)
	_animate_idle(player_node)

	enemy_node = _create_stick_figure(Color(1.0, 0.2, 0.4), false)
	enemy_node.position = Vector2(850, 480)
	enemy_node.scale.x = -1
	add_child(enemy_node)
	_add_hat(enemy_node, "Cap", Color(0.2, 1.0, 0.4))
	enemy_sword = _add_sword(enemy_node)
	_animate_idle(enemy_node)

	# UI
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	hp_label_player = _create_label(Vector2(50, 50), "PLAYER", Color(0.2, 0.8, 1.0))
	hp_label_enemy = _create_label(Vector2(900, 50), "ENEMY", Color(1.0, 0.2, 0.4))
	status_label = _create_label(Vector2(0, 150), "", Color.YELLOW)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size = Vector2(1152, 50)
	
	# Energy Bar
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.size = Vector2(200, 20)
	bar_bg.position = Vector2(50, 100)
	ui_layer.add_child(bar_bg)
	
	energy_bar = ColorRect.new()
	energy_bar.color = Color(1.0, 0.5, 0.0) # Orange
	energy_bar.size = Vector2(0, 20)
	energy_bar.position = Vector2(50, 100)
	ui_layer.add_child(energy_bar)
	
	var en_label = Label.new()
	en_label.text = "SANDEVISTAN [SPACE]"
	en_label.position = Vector2(50, 80)
	en_label.scale = Vector2(0.8, 0.8)
	ui_layer.add_child(en_label)

	# Overlay
	swipe_overlay = Node2D.new()
	ui_layer.add_child(swipe_overlay)
	
	guide_line = Line2D.new()
	guide_line.width = 40
	guide_line.default_color = Color(1, 1, 1, 0.1)
	guide_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	guide_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	guide_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	swipe_overlay.add_child(guide_line)
	
	guide_arrow = Line2D.new()
	guide_arrow.width = 10
	guide_arrow.default_color = Color(0.5, 1.0, 0.5, 0.8)
	swipe_overlay.add_child(guide_arrow)
	
	drag_trail = Line2D.new()
	drag_trail.width = 8
	drag_trail.default_color = Color.CYAN
	swipe_overlay.add_child(drag_trail)
	
	slash_line = Line2D.new()
	slash_line.width = 6
	slash_line.default_color = Color(1, 1, 1, 0.8)
	add_child(slash_line) # In world space for shake compatibility

func _create_label(pos, text, color):
	var l = Label.new()
	l.position = pos
	l.text = text
	l.modulate = color
	l.scale = Vector2(1.5, 1.5)
	ui_layer.add_child(l)
	return l

func _create_stick_figure(color, is_player):
	var node = Node2D.new()
	
	var body = Line2D.new()
	body.width = 6
	body.default_color = color
	body.add_point(Vector2(0, 0))
	body.add_point(Vector2(0, -60))
	node.add_child(body)
	
	var head = Line2D.new()
	head.width = 6
	head.default_color = color
	_create_circle(head, 15)
	head.position = Vector2(0, -80)
	node.add_child(head)
	
	var arms = Line2D.new()
	arms.width = 6
	arms.default_color = color
	arms.add_point(Vector2(-20, -30))
	arms.add_point(Vector2(0, -60))
	arms.add_point(Vector2(20, -30))
	node.add_child(arms)
	
	var legs = Line2D.new()
	legs.width = 6
	legs.default_color = color
	legs.add_point(Vector2(-15, 0))
	legs.add_point(Vector2(0, 0))
	legs.add_point(Vector2(15, 0))
	node.add_child(legs)
	
	return node

func _create_circle(line, radius):
	for i in range(17):
		var angle = i * TAU / 16.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)

func _add_hat(parent, type, color):
	var head = parent.get_child(1)
	var hat = Node2D.new()
	hat.position = Vector2(0, -15)
	head.add_child(hat)
	
	var line = Line2D.new()
	line.default_color = color
	line.width = 4
	hat.add_child(line)
	
	if type == "TopHat":
		line.add_point(Vector2(-20, 0))
		line.add_point(Vector2(20, 0))
		var sub = Line2D.new()
		sub.default_color = color; sub.width=4
		sub.add_point(Vector2(12, 0)); sub.add_point(Vector2(12, -30))
		sub.add_point(Vector2(-12, -30)); sub.add_point(Vector2(-12, 0))
		hat.add_child(sub)
	elif type == "Cap":
		for i in range(9):
			var a = PI + (i * PI / 8.0)
			line.add_point(Vector2(cos(a), sin(a)*0.8)*16)
		line.add_point(Vector2(16, 0))
		line.add_point(Vector2(28, 5))

func _add_sword(parent):
	var arms = parent.get_child(2)
	# Right hand is index 2
	var hand_pos = arms.get_point_position(2)
	
	var sword_node = Node2D.new()
	sword_node.position = hand_pos
	arms.add_child(sword_node)
	
	var blade = Line2D.new()
	blade.points = [Vector2(0,0), Vector2(10, -50)]
	blade.default_color = Color(0.8, 1.0, 1.0)
	blade.width = 3
	sword_node.add_child(blade)
	
	var hilt = Line2D.new() # Crossguard
	hilt.points = [Vector2(-5, -5), Vector2(8, 2)]
	hilt.default_color = Color.GRAY
	hilt.width = 4
	sword_node.add_child(hilt)
	
	return sword_node

func _animate_idle(node):
	var tween = create_tween().set_loops()
	var s = 1.0 if node == player_node else -1.0
	tween.tween_property(node, "scale", Vector2(s * 1.05, 0.95), 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", Vector2(s * 0.95, 1.05), 1.0).set_trans(Tween.TRANS_SINE)


# --- Game Logic ---

func _process(delta):
	# Update Energy Bar
	energy_bar.size.x = (energy / 100.0) * 200.0
	
	# Sandevistan Input
	if Input.is_action_just_pressed("ui_accept") and not is_sandevistan and current_turn == "Player" and energy >= 100:
		_activate_sandevistan()

	if swipe_active:
		swipe_time_left -= delta / Engine.time_scale
		
		# Feedback color
		var ratio = swipe_time_left / swipe_duration
		guide_line.default_color.a = 0.1 + (ratio * 0.2)
		
		if swipe_time_left <= 0:
			_fail_swipe("TOO SLOW")
	
	if is_dragging:
		drag_trail.add_point(swipe_overlay.get_local_mouse_position())
		if drag_trail.get_point_count() > 10:
			drag_trail.remove_point(0)

func _input(event):
	if not swipe_active: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start = event.position
				drag_trail.clear_points()
				drag_trail.add_point(drag_start)
			else:
				# Release
				if is_dragging:
					is_dragging = false
					var drag_end = event.position
					_process_swipe(drag_start, drag_end)

func _start_battle():
	player_hp = PLAYER_HP_MAX
	enemy_hp = ENEMY_HP_MAX
	energy = 50
	_update_ui()
	_start_player_turn()

func _start_player_turn():
	current_turn = "Player"
	combo_count = 0
	_status("YOUR TURN")
	await get_tree().create_timer(1.0).timeout
	_next_combo_step()

func _next_combo_step():
	if combo_count >= MAX_COMBO:
		_end_player_turn()
		return
		
	swipe_active = true
	is_dragging = false
	drag_trail.clear_points()
	guide_line.visible = true
	guide_arrow.visible = true
	
	# Difficulty logic
	var duration_base = 1.2 if not is_sandevistan else 0.5
	swipe_duration = duration_base - (combo_count * 0.1)
	swipe_time_left = swipe_duration
	
	# Generate Direction
	# If continuing combo, try to flow (e.g. Right -> Left)
	# For now, just random angles
	randomize()
	required_angle = randf() * TAU
	
	# Visuals on Enemy
	var center = enemy_node.position + Vector2(0, -40)
	var radius = 100.0
	var offset = Vector2(cos(required_angle), sin(required_angle)) * radius
	
	swipe_start_pos = center - offset
	swipe_end_pos = center + offset
	
	guide_line.clear_points()
	guide_line.add_point(swipe_start_pos)
	guide_line.add_point(swipe_end_pos)
	
	# Arrow tip
	guide_arrow.clear_points()
	guide_arrow.add_point(swipe_end_pos - (offset.normalized() * 20) + (offset.orthogonal().normalized()*10))
	guide_arrow.add_point(swipe_end_pos)
	guide_arrow.add_point(swipe_end_pos - (offset.normalized() * 20) - (offset.orthogonal().normalized()*10))

func _process_swipe(start, end):
	var vector = end - start
	if vector.length() < 50:
		return # Too short
	
	var angle = vector.angle()
	# Compare angle with required_angle
	# Dot product of normalized vectors
	var swipe_dir = vector.normalized()
	var req_dir = (swipe_end_pos - swipe_start_pos).normalized()
	var accuracy = swipe_dir.dot(req_dir)
	
	if accuracy > 0.8:
		# Success
		_succeed_swipe(accuracy)
	elif accuracy < -0.8:
		# Wrong direction
		_fail_swipe("WRONG WAY")
	else:
		_fail_swipe("BAD ANGLE")

func _succeed_swipe(accuracy):
	swipe_active = false
	guide_line.visible = false
	guide_arrow.visible = false
	
	# Calculations
	var damage = BASE_DAMAGE * (1.0 + (combo_count * 0.2))
	var note = "GOOD"
	var shake = 2.0
	
	if accuracy > 0.95 and swipe_time_left > swipe_duration * 0.3:
		note = "PERFECT!"
		damage *= 1.5
		shake = 5.0
		energy = min(100, energy + 15)
	else:
		energy = min(100, energy + 5)
	
	if is_sandevistan:
		note = "SLICED"
		damage *= 0.5 # Balance for rapid fire
	
	# Apply
	enemy_hp = max(0, enemy_hp - damage)
	combo_count += 1
	
	# Juice
	_slash_effect(swipe_start_pos, swipe_end_pos)
	_pop_text(enemy_node.position, note + " " + str(int(damage)))
	_shake_screen(shake)
	_update_ui()
	
	if enemy_hp <= 0:
		_check_game_over()
		return
	
	# Chain
	var delay = 0.2 if is_sandevistan else 0.5
	await get_tree().create_timer(delay).timeout
	_next_combo_step()

func _fail_swipe(reason):
	swipe_active = false
	guide_line.visible = false
	guide_arrow.visible = false
	
	_pop_text(enemy_node.position, reason, Color.RED)
	combo_count = 0 # Reset combo
	
	if is_sandevistan:
		# Just wait for next target or time out
		await get_tree().create_timer(0.2).timeout
		_next_combo_step()
	else:
		_end_player_turn()

func _end_player_turn():
	if is_sandevistan:
		_deactivate_sandevistan()
	
	current_turn = "Enemy"
	_status("ENEMY TURN")
	await get_tree().create_timer(1.0).timeout
	_enemy_attack()

func _enemy_attack():
	_animate_lunge(enemy_node, player_node)
	await get_tree().create_timer(0.3).timeout
	
	var dmg = 15
	if randf() > 0.8:
		dmg *= 2
		_shake_screen(8.0)
		_pop_text(player_node.position, "CRITICAL HIT!", Color.RED)
	else:
		_pop_text(player_node.position, "HIT", Color.ORANGE)
	
	player_hp = max(0, player_hp - dmg)
	_update_ui()
	
	if player_hp <= 0:
		_check_game_over()
	else:
		await get_tree().create_timer(1.0).timeout
		_start_player_turn()

# --- Sandevistan ---
func _activate_sandevistan():
	is_sandevistan = true
	energy = 0
	Engine.time_scale = 0.3
	_status("SANDEVISTAN ACTIVATED")
	
	# Visual
	var chromatic = WorldEnvironment.new() # Placeholder for effect
	
	# Timer
	var t = get_tree().create_timer(SANDEVISTAN_DURATION * Engine.time_scale)
	t.timeout.connect(_deactivate_sandevistan)
	
	_next_combo_step()

func _deactivate_sandevistan():
	if not is_sandevistan: return
	is_sandevistan = false
	Engine.time_scale = 1.0
	_status("TIME RESUMED")
	if current_turn == "Player":
		_end_player_turn()

# --- VisualFX ---

func _slash_effect(start, end):
	slash_line.clear_points()
	slash_line.add_point(start)
	slash_line.add_point(end)
	slash_line.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(slash_line, "modulate:a", 0.0, 0.3)

func _pop_text(pos, text, color=Color.WHITE):
	var l = Label.new()
	l.text = text
	l.position = pos + Vector2(randf_range(-20,20), -50)
	l.modulate = color
	ui_layer.add_child(l)
	
	var tween = create_tween()
	tween.tween_property(l, "position:y", l.position.y - 50, 0.5)
	tween.tween_property(l, "modulate:a", 0.0, 0.5)
	tween.tween_callback(l.queue_free)

func _shake_screen(amount):
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(self, "position", Vector2(randf(), randf()) * amount, 0.05)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)

func _animate_lunge(attacker, target):
	var start = attacker.position
	var end = target.position + Vector2(50 if attacker.scale.x > 0 else -50, 0)
	var tween = create_tween()
	tween.tween_property(attacker, "position", end, 0.1).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(attacker, "position", start, 0.4).set_trans(Tween.TRANS_ELASTIC)

func _status(t):
	status_label.text = t
	status_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(status_label, "modulate:a", 0.0, 2.0)

func _update_ui():
	hp_label_player.text = "HP: " + str(player_hp)
	hp_label_enemy.text = "HP: " + str(enemy_hp)
	
func _check_game_over():
	if player_hp <= 0:
		_status("DEFEAT")
		await get_tree().create_timer(2).timeout
		get_tree().reload_current_scene()
	elif enemy_hp <= 0:
		_status("VICTORY")
		await get_tree().create_timer(2).timeout
		get_tree().reload_current_scene()
