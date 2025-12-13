extends Node2D

# Config
const PLAYER_HP_MAX = 100
const ENEMY_HP_MAX = 100
const BASE_DAMAGE = 15
const DIFFICULTY = 2 # 1-3

# State
var player_hp = PLAYER_HP_MAX
var enemy_hp = ENEMY_HP_MAX
var current_turn = "Player" # "Player" or "Enemy"

# Swipe State
var swipe_active = false
var swipe_start_pos = Vector2()
var swipe_end_pos = Vector2()
var is_dragging = false
var swipe_time_left = 0.0
var swipe_duration = 0.0

# UI Nodes
var ui_layer
var hp_label_player
var hp_label_enemy
var status_label

# Swipe Visuals
var swipe_container
var start_circle
var end_circle
var swipe_line
var timer_bar

# Game Nodes
var player_rect
var enemy_rect

func _ready():
	_setup_visuals()
	_update_ui()
	_start_battle()

func _setup_visuals():
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1)
	bg.size = get_viewport_rect().size
	add_child(bg)

	# Arena Floor
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.3, 0.3, 0.3)
	floor_rect.size = Vector2(800, 200)
	floor_rect.position = Vector2(176, 400)
	add_child(floor_rect)

	# Player
	player_rect = ColorRect.new()
	player_rect.color = Color(0.2, 0.6, 1.0) # Blue
	player_rect.size = Vector2(64, 128)
	player_rect.position = Vector2(250, 272)
	add_child(player_rect)

	# Enemy
	enemy_rect = ColorRect.new()
	enemy_rect.color = Color(1.0, 0.3, 0.3) # Red
	enemy_rect.size = Vector2(64, 128)
	enemy_rect.position = Vector2(850, 272)
	add_child(enemy_rect)

	# UI Layer
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	# Stats UI
	hp_label_player = Label.new()
	hp_label_player.position = Vector2(50, 50)
	hp_label_player.modulate = Color(0.4, 0.8, 1.0) 
	hp_label_player.text = "PLAYER HP: 100"
	ui_layer.add_child(hp_label_player)

	hp_label_enemy = Label.new()
	hp_label_enemy.position = Vector2(900, 50)
	hp_label_enemy.modulate = Color(1.0, 0.5, 0.5)
	hp_label_enemy.text = "ENEMY HP: 100"
	ui_layer.add_child(hp_label_enemy)

	status_label = Label.new()
	status_label.position = Vector2(0, 150)
	status_label.size = Vector2(1152, 50)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.text = "BATTLE START!"
	ui_layer.add_child(status_label)

	# Swipe Container
	swipe_container = Control.new()
	ui_layer.add_child(swipe_container)
	
	swipe_line = Line2D.new()
	swipe_line.width = 10.0
	swipe_line.default_color = Color(1, 1, 1, 0.5)
	swipe_container.add_child(swipe_line)
	
	start_circle = ColorRect.new() # Using Rect as simple 'circle' proxy
	start_circle.color = Color.GREEN
	start_circle.size = Vector2(40, 40)
	swipe_container.add_child(start_circle)
	
	end_circle = ColorRect.new()
	end_circle.color = Color.RED
	end_circle.size = Vector2(40, 40)
	swipe_container.add_child(end_circle)
	
	timer_bar = ColorRect.new()
	timer_bar.color = Color.CYAN
	timer_bar.size = Vector2(0, 5)
	timer_bar.position = Vector2(0, 0)
	swipe_container.add_child(timer_bar)
	
	swipe_container.visible = false

func _process(delta):
	if swipe_active:
		swipe_time_left -= delta
		
		# Update Timer Bar
		if swipe_duration > 0:
			var ratio = swipe_time_left / swipe_duration
			timer_bar.size = Vector2(100 * ratio, 10)
			timer_bar.position = start_circle.position + Vector2(0, -20)
		
		if swipe_time_left <= 0:
			_fail_swipe("TOO SLOW!")

func _input(event):
	if not swipe_active:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if clicked near start
				if start_circle.get_global_rect().has_point(event.position):
					is_dragging = true
					start_circle.color = Color.YELLOW # Feedback
			else:
				# Released
				if is_dragging:
					is_dragging = false
					# Check if released near end
					if end_circle.get_global_rect().has_point(event.position):
						_succeed_swipe()
					else:
						_fail_swipe("MISSED END!")

func _start_battle():
	player_hp = PLAYER_HP_MAX
	enemy_hp = ENEMY_HP_MAX
	_update_ui()
	_start_player_turn()

func _start_player_turn():
	current_turn = "Player"
	status_label.text = "PLAYER TURN! SWIPE GREEN -> RED!"
	_generate_swipe()

func _generate_swipe():
	swipe_active = true
	is_dragging = false
	swipe_container.visible = true
	
	# Difficulty settings
	var window = 2.0 - (DIFFICULTY * 0.4) # 1.6s, 1.2s, 0.8s
	swipe_duration = window
	swipe_time_left = window
	
	# Random positions near enemy
	var center = enemy_rect.position + enemy_rect.size / 2.0
	var offset_range = 100 + (DIFFICULTY * 30)
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * offset_range
	
	swipe_start_pos = center - offset
	swipe_end_pos = center + offset
	
	# Update visuals
	start_circle.position = swipe_start_pos - start_circle.size / 2.0
	end_circle.position = swipe_end_pos - end_circle.size / 2.0
	start_circle.color = Color.GREEN
	
	swipe_line.clear_points()
	swipe_line.add_point(swipe_start_pos)
	swipe_line.add_point(swipe_end_pos)

func _succeed_swipe():
	swipe_active = false
	swipe_container.visible = false
	
	# Perfect logic could be speed based, for now just success
	var damage = BASE_DAMAGE
	
	# Fast swipe = Critical?
	if swipe_time_left > swipe_duration * 0.5:
		damage *= 2
		_show_feedback("FAST SWIPE! CRITICAL! %d DMG" % damage)
	else:
		_show_feedback("GOOD! %d DMG" % damage)

	enemy_hp = max(0, enemy_hp - damage)
	_update_ui()
	
	if enemy_hp <= 0:
		_check_game_over()
	else:
		await get_tree().create_timer(1.0).timeout
		_start_enemy_turn()

func _fail_swipe(reason):
	swipe_active = false
	swipe_container.visible = false
	_show_feedback(reason + " 0 DMG")
	
	await get_tree().create_timer(1.0).timeout
	_start_enemy_turn()

func _start_enemy_turn():
	current_turn = "Enemy"
	status_label.text = "ENEMY ATTACKING..."
	
	await get_tree().create_timer(1.5).timeout
	
	# Simulate Enemy Attack
	var roll = randf()
	var damage = BASE_DAMAGE
	var result_text = "ENEMY HIT!"
	
	if roll > 0.8:
		damage *= 2
		result_text = "CRITICAL HIT by ENEMY!"
	elif roll < 0.2:
		damage = 0
		result_text = "ENEMY MISSED!"

	player_hp = max(0, player_hp - damage)
	_show_feedback(result_text)
	_update_ui()
	_check_game_over()
	
	if player_hp > 0:
		_start_player_turn()

func _show_feedback(text):
	status_label.text = text

func _update_ui():
	hp_label_player.text = "PLAYER HP: %d / %d" % [player_hp, PLAYER_HP_MAX]
	hp_label_enemy.text = "ENEMY HP: %d / %d" % [enemy_hp, ENEMY_HP_MAX]

func _check_game_over():
	if player_hp <= 0:
		status_label.text = "DEFEAT! RELOADING..."
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()
	elif enemy_hp <= 0:
		status_label.text = "VICTORY! RELOADING..."
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()
