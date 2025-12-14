extends Node2D

# Config
const PLAYER_HP_MAX = 100
const ENEMY_HP_MAX = 300
const BASE_DAMAGE = 10
const MAX_COMBO = 5
const SANDEVISTAN_DURATION = 2.0

const SwipeInputSrc = preload("res://scenes/combat/SwipeInput.gd")

# State
var player_hp = PLAYER_HP_MAX
var enemy_hp = ENEMY_HP_MAX
var energy = 0
var current_turn = "Player"
var combo_count = 0
var is_sandevistan = false

# Components
var player: Character
var enemy: Character
var hud: HUD
var swipe_input: SwipeInputSrc
var ui_layer: CanvasLayer
var current_step_timer: SceneTreeTimer
var current_step_duration: float = 0.0
var sandevistan_duration_timer: SceneTreeTimer

# Visuals managed by Main
# Visuals managed by Main
# slash_line replaced by local instances

func _ready():
	randomize()
	_setup_environment()
	_setup_visuals()
	_start_battle()

func _setup_environment():
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world_env.environment = env
	add_child(world_env)
	
	# Basic static visuals (BG/Floor)
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.1)
	bg.size = get_viewport_rect().size
	add_child(bg)
	
	var floor_line = Line2D.new()
	floor_line.default_color = Color(0.0, 1.0, 1.0, 0.5)
	floor_line.width = 4
	floor_line.add_point(Vector2(50, 500))
	floor_line.add_point(Vector2(1100, 500))
	add_child(floor_line)
	
	# Slash Vfx
	# Instantiated per-attack in _slash_effect

func _setup_visuals():
	# Characters
	player = Character.new()
	player.setup(Color.CYAN, true)
	# Skeleton is ~80 units tall (hip to feet), so position at 500-80=420
	player.set_origin(Vector2(100, 420))
	player.position = Vector2(100, 420)
	add_child(player)
	
	enemy = Character.new()
	enemy.position = Vector2(1000, 420)
	enemy.setup(Color.RED, false)
	enemy.set_origin(Vector2(1000, 420))
	enemy.scale.x = -1
	add_child(enemy)
	
	# UI Layer
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# HUD
	hud = load("res://scenes/ui/HUD.tscn").instantiate()
	ui_layer.add_child(hud)
	
	# Victory Screen
	var victory_screen = load("res://scenes/ui/VictoryScreen.tscn").instantiate()
	add_child(victory_screen)
	victory_screen.continue_pressed.connect(_on_victory_continue)
	set_meta("victory_screen", victory_screen)
	
	# Swipe Input (Adding to UI layer to keep it stable vs screen shake, 
	# but could also be in world if we want trails to follow world. 
	# Original code had it in UI layer.)
	swipe_input = SwipeInputSrc.new()
	ui_layer.add_child(swipe_input)
	
	# Signals
	swipe_input.swipe_ended.connect(_on_swipe_ended)
	swipe_input.swipe_updated.connect(_on_swipe_updated)
	swipe_input.swipe_started.connect(_on_swipe_started)

func _start_battle():
	player_hp = PLAYER_HP_MAX
	enemy_hp = ENEMY_HP_MAX
	energy = 50
	
	hud.update_health(player_hp, enemy_hp)
	hud.update_energy(energy)
	
	_start_player_turn()

func _process(_delta):
	# Sandevistan Input
	if Input.is_action_just_pressed("ui_accept") and not is_sandevistan and current_turn == "Player" and energy >= 100:
		_activate_sandevistan()
		
	# Sandevistan Visuals
	if is_sandevistan and sandevistan_duration_timer and sandevistan_duration_timer.time_left > 0:
		var percent = sandevistan_duration_timer.time_left / SANDEVISTAN_DURATION
		swipe_input.update_sandevistan_timer(
			swipe_input.target_circle.position,
			percent
		)
	elif is_sandevistan and sandevistan_duration_timer and sandevistan_duration_timer.time_left <= 0:
		pass # Handled by timeout signal

	# Swipe Timeout Logic
	if swipe_input.input_enabled and not is_sandevistan:
		# Update timer visual
		if current_step_timer and current_step_timer.time_left > 0:
			var percent = current_step_timer.time_left / current_step_duration
			swipe_input.update_timer(
				swipe_input.get_meta("required_start", Vector2()),
				swipe_input.get_meta("required_end", Vector2()),
				percent
			)
		else:
			swipe_input.hide_timer()

# --- Turn Logic ---


func _next_combo_step():
	# Normal mode: Limit combo
	# Sandevistan: Unlimited attacks until time runs out
	if not is_sandevistan and combo_count >= MAX_COMBO:
		_end_player_turn()
		return
		
	# Setup Swipe
	swipe_input.set_active(true)
	
	var duration_base = 1.2 if not is_sandevistan else 0.5
	var reduction = combo_count * (0.02 if is_sandevistan else 0.1)
	var duration = max(0.2, duration_base - reduction)
	
	# Timeout Timer
	# First move = wait for swipe (handled in _on_swipe_started)
	# Subsequent moves = immediate pressure
	if not is_sandevistan and combo_count > 0:
		current_step_duration = duration
		current_step_timer = get_tree().create_timer(duration)
		current_step_timer.timeout.connect(_on_swipe_timeout.bind(combo_count), CONNECT_ONE_SHOT)
	
	if is_sandevistan:
		# Fruit Ninja Mode
		swipe_input.show_target_circle(enemy.position + Vector2(0, -40))
		# Hide guide lines handled by show_target_circle implicitly (since guide is separate)
	else:
		# Normal Mode directions
		randomize()
		var required_angle = randf() * TAU
		var center = enemy.position + Vector2(0, -40)
		var radius = 100.0
		var offset = Vector2(cos(required_angle), sin(required_angle)) * radius
		var start = center - offset
		var end = center + offset
		
		swipe_input.show_guide(start, end)
		swipe_input.set_meta("required_start", start)
		swipe_input.set_meta("required_end", end)

func _on_swipe_updated(pos):
	if is_sandevistan:
		var center = swipe_input.target_circle.position
		# Check distance
		if pos.distance_to(center) < 40:
			# Hit!
			# Hit!
			_handle_sandevistan_hit()

func _on_swipe_started(_pos):
	if is_sandevistan: return
	
	# Only start timer here for the FIRST move (infinite patience).
	# Subsequent moves have timer started in _next_combo_step to maintain rhythm.
	if combo_count == 0:
		var duration_base = 1.2
		var reduction = combo_count * 0.1
		var duration = max(0.2, duration_base - reduction)
		
		current_step_duration = duration
		current_step_timer = get_tree().create_timer(duration)
		current_step_timer.timeout.connect(_on_swipe_timeout.bind(combo_count), CONNECT_ONE_SHOT)

func _on_swipe_ended(start, end):
	if is_sandevistan: return # Continuous input handled in updated
	
	var req_start = swipe_input.get_meta("required_start", Vector2())
	var req_end = swipe_input.get_meta("required_end", Vector2())
	
	if req_start == Vector2(): return
	
	var vector = end - start
	var swipe_dir = vector.normalized()
	var req_dir = (req_end - req_start).normalized()
	var accuracy = swipe_dir.dot(req_dir)
	
	if accuracy > 0.8:
		_succeed_swipe(accuracy)
	else:
		_fail_swipe("BAD ANGLE")

func _succeed_swipe(accuracy):
	swipe_input.set_active(false)
	swipe_input.hide_timer()
	
	var damage = BASE_DAMAGE * (1.0 + (combo_count * 0.2))
	var note = "GOOD"
	var shake_amt = 2.0
	
	if accuracy > 0.95:
		note = "PERFECT!"
		damage *= 1.5
		shake_amt = 5.0
		energy = min(100, energy + 15)
	else:
		energy = min(100, energy + 5)
		
	enemy_hp = max(0, enemy_hp - damage)
	combo_count += 1
	
	hud.update_health(player_hp, enemy_hp)
	hud.update_energy(energy)
	hud.pop_text(enemy.position, note + " " + str(int(damage)))
	_shake_screen(shake_amt)
	_slash_effect(swipe_input.get_meta("required_start"), swipe_input.get_meta("required_end"))
	player.play_sword_swing()
	player.play_attack_pose()
	
	if enemy_hp <= 0:
		_game_over(true)
	else:
		await get_tree().create_timer(0.2).timeout
		_next_combo_step()

func _fail_swipe(reason):
	swipe_input.set_active(false)
	swipe_input.hide_all_timers()
	hud.pop_text(enemy.position, reason, Color.RED)
	combo_count = 0
	_end_player_turn()

func _on_swipe_timeout(step_index):
	# Verify we are still on the same step and haven't succeeded yet
	if current_turn == "Player" and swipe_input.input_enabled and not is_sandevistan:
		# Check if we moved on (hacky check: if combo count changed)
		if step_index == combo_count:
			_fail_swipe("TOO SLOW")

# --- Sandevistan Specifics ---
func _activate_sandevistan():
	is_sandevistan = true
	energy = 0
	combo_count = 0 # Reset combo to give full 5 attacks
	Engine.time_scale = 0.3
	hud.update_energy(0)
	hud.show_status("SANDEVISTAN ACTIVATED")
	
	# Use ignore_time_scale=true so it lasts 3 real seconds (not 10s of game time)
	sandevistan_duration_timer = get_tree().create_timer(SANDEVISTAN_DURATION, true, false, true)
	sandevistan_duration_timer.timeout.connect(_deactivate_sandevistan)
	
	# If we were waiting for turn, interrupt?
	# Usually activated during idle or turn.
	if current_turn == "Player":
		_next_combo_step() # Force next step immediately if stalled

func _deactivate_sandevistan():
	if not is_sandevistan: return
	is_sandevistan = false
	swipe_input.hide_all_timers()
	Engine.time_scale = 1.0
	hud.show_status("TIME RESUMED")
	if current_turn == "Player":
		_end_player_turn()

func _handle_sandevistan_hit():
	# Use a cooldown to prevent update spam
	if enemy.get_meta("hit_cooldown", 0) > Time.get_ticks_msec():
		return
	enemy.set_meta("hit_cooldown", Time.get_ticks_msec() + 100)
	
	swipe_input.animate_target_hit()
	player.play_sword_swing()
	
	var damage = BASE_DAMAGE * 0.5
	enemy_hp = max(0, enemy_hp - damage)
	combo_count += 1
	energy = min(100, energy + 2)
	
	hud.update_health(player_hp, enemy_hp)
	hud.update_energy(energy)
	hud.pop_text(enemy.position, "SLICE " + str(int(damage)), Color.YELLOW)
	
	_spawn_blood(swipe_input.target_circle.position)
	_spawn_blood(enemy.position)
	
	# Generate a random slash angle through the center
	randomize()
	var angle = randf() * TAU
	var length = 150.0
	var center = swipe_input.target_circle.position
	var start = center - Vector2(cos(angle), sin(angle)) * length
	var end = center + Vector2(cos(angle), sin(angle)) * length

	
	_slash_effect(start, end)
	player.play_sword_swing(true) # Fast swing for Sandevistan
	player.play_attack_pose(true) # Fast body animation
	
	if enemy_hp <= 0:
		_game_over(true)
	else:
		# Move target
		_next_combo_step()

func _end_player_turn():
	if current_turn == "Enemy": return
	current_turn = "Enemy"
	
	swipe_input.set_active(false)
	swipe_input.hide_all_timers()
	if is_sandevistan: _deactivate_sandevistan()
	
	hud.show_status("ENEMY TURN")
	
	# Player returns, Enemy runs up
	await player.return_to_origin()
	await enemy.run_to(player.position + Vector2(150, 0))
	
	await get_tree().create_timer(0.5).timeout
	_enemy_attack()

func _enemy_attack():
	# Enemy swing
	enemy.play_sword_swing()
	enemy.play_attack_pose()
	
	# Simple damage logic for now
	# In real game, enemy might have combo or patterns
	player_hp = max(0, player_hp - 5)
	hud.update_health(player_hp, enemy_hp)
	hud.pop_text(player.position, "Hit -5", Color.RED)
	_spawn_blood(player.position)
	
	await get_tree().create_timer(1.0).timeout
	
	# Enemy returns, Player runs up
	await enemy.return_to_origin()
	
	if player_hp <= 0:
		_game_over(false)
	else:
		_start_player_turn()

func _start_player_turn():
	current_turn = "Player"
	combo_count = 0
	hud.show_status("PLAYER TURN")
	await player.run_to(enemy.position - Vector2(150, 0))
	_next_combo_step()

func _game_over(win):
	if win:
		# Victory sequence
		hud.show_status("VICTORY!")
		await enemy.play_death()
		await get_tree().create_timer(0.5).timeout
		
		var victory_screen = get_meta("victory_screen")
		victory_screen.show_victory()
	else:
		# Defeat
		hud.show_status("DEFEAT")
		await get_tree().create_timer(2).timeout
		get_tree().reload_current_scene()

func _on_victory_continue():
	get_tree().reload_current_scene()

# --- Visual Effects ---

func _shake_screen(amount):
	var tween = create_tween()
	for i in range(5):
		tween.tween_property(self, "position", Vector2(randf(), randf()) * amount, 0.05)
	tween.tween_property(self, "position", Vector2.ZERO, 0.05)

func _slash_effect(start, end):
	# Create a new Sprite2D for this specific slash
	var sprite = Sprite2D.new()
	sprite.texture = load("res://assets/slash_clean.png")
	sprite.z_index = 100 # Draw on top
	add_child(sprite)
	
	# Transform
	var center = (start + end) / 2.0
	var dir = end - start
	var length = dir.length()
	
	sprite.position = center
	sprite.rotation = dir.angle()
	
	# Scale setup: Assume texture is roughly 256px or similar, adjust scale to match swipe length
	# Adjust base_scale based on your texture's actual size. 
	# If texture is ~500px, 1.0 = 500px slash.
	var base_scale_x = length / 500.0
	sprite.scale = Vector2(base_scale_x * 0.5, base_scale_x * 0.8) # Start small
	sprite.modulate.a = 1.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Flash open and fade
	tween.tween_property(sprite, "scale", Vector2(base_scale_x * 1.2, base_scale_x * 1.2), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25).set_delay(0.05)
	
	# Cleanup
	tween.chain().tween_callback(sprite.queue_free)

func _spawn_blood(pos):
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.amount = 16
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 300
	particles.scale_amount_min = 4
	particles.scale_amount_max = 8
	particles.color = Color(1.0, 0.0, 0.0)
	add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(1.2).timeout
	particles.queue_free()
