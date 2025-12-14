extends Node2D

# Config
const PLAYER_HP_MAX = 100
const ENEMY_HP_MAX = 300
const BASE_DAMAGE = 10
const MAX_COMBO = 5
const SANDEVISTAN_DURATION = 2.0

const SwipeInputSrc = preload("res://scenes/combat/SwipeInput.gd")
const DefenseGameSrc = preload("res://scenes/combat/DefenseGame.gd")

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
var defense_game: Control
var ui_layer: CanvasLayer
var current_step_timer: SceneTreeTimer
var current_step_duration: float = 0.0
var sandevistan_duration_timer: SceneTreeTimer

# Visuals managed by Main
# slash_line replaced by local instances

func _ready():
	y_sort_enabled = true # Enable depth sorting
	randomize()
	_setup_environment()
	_setup_visuals()
	_start_battle()

# ... (Environment setup omitted, remains same) ...

# ... (Visuals setup omitted, remains same) ...

# ... (Battle/HP logic omitted, remains same) ...

# ... (Process logic omitted, remains same) ...

# ... (Turn logic omitted, remains same) ...

func _enemy_attack():
	# Enemy prepares to attack
	hud.show_status("DEFEND! CLICK 1-5!")
	
	# Start Defense Game
	defense_game.start_game(2.5, player.position) # 2.5 seconds to click 5 numbers, centered on player

func _on_defense_success():
	# Blocked!
	hud.pop_text(player.position, "BLOCKED!", Color.CYAN)
	_finish_enemy_attack(0) # 0 damage
	
func _on_defense_fail():
	# Failed!
	hud.pop_text(player.position, "FAILED!", Color.RED)
	_finish_enemy_attack(BASE_DAMAGE) # Full damage

func _finish_enemy_attack(damage_amount):
	# Enemy swing visuals
	enemy.play_sword_swing()
	enemy.play_attack_pose()
	
	if damage_amount > 0:
		player_hp = max(0, player_hp - damage_amount)
		hud.pop_text(player.position, "Hit -" + str(damage_amount), Color.RED)
		_spawn_blood(player.position)
		_shake_screen(3.0)
	else:
		# Block effect (Sparks)
		_spawn_blood(player.position + Vector2(0, -50)) # Reusing blood for now, maybe change color next?
	
	_update_all_hp()
	
	await get_tree().create_timer(1.0).timeout
	
	# Enemy returns, Player runs up
	await enemy.return_to_origin()
	
	if player_hp <= 0:
		_game_over(false)
	else:
		_start_player_turn()


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
	bg.z_index = -100 # Keep BG behind everything
	add_child(bg)
	
	# Arena Floor Grid (2.5D perspective hint)
	var grid_holder = Node2D.new()
	grid_holder.z_index = -50
	add_child(grid_holder)
	
	var grid_color = Color(0.0, 1.0, 1.0, 0.1)
	var center = get_viewport_rect().size / 2.0
	
	# Draw perspective lines
	for i in range(-5, 6):
		var line = Line2D.new()
		line.width = 2
		line.default_color = grid_color
		# Vertical-ish diverging lines
		var x_offset = i * 150 # Wider grid
		line.add_point(Vector2(center.x + (x_offset * 0.2), 200)) # Horizon (Vanishing point approx)
		line.add_point(Vector2(center.x + (x_offset * 1.5), 1080)) # Bottom
		grid_holder.add_child(line)
		
	# Draw horizontal lines
	for i in range(12):
		var line = Line2D.new()
		line.width = 2
		line.default_color = grid_color
		var y = 300 + (pow(i, 1.2) * 45) # Exponential spacing for perspective
		if y > 1080: break
		
		# Width increases with Y
		var far_width = 1200.0
		var close_width = 3000.0
		var progress = (y - 300) / 780.0
		var current_width = lerp(far_width, close_width, progress)
		
		line.add_point(Vector2(center.x - (current_width * 0.5), y))
		line.add_point(Vector2(center.x + (current_width * 0.5), y))
		grid_holder.add_child(line)

func _setup_visuals():
	var screen_size = get_viewport_rect().size
	var center_x = screen_size.x / 2.0
	
	# Characters
	player = Character.new()
	player.setup(Color.CYAN, true)
	# Player at Bottom Center
	var p_pos = Vector2(center_x, screen_size.y - 150) # Slight offset left
	player.set_origin(p_pos)
	player.position = p_pos
	add_child(player)
	
	enemy = Character.new()
	enemy.setup(Color.RED, false)
	# Enemy at Top Center
	var e_pos = Vector2(center_x, screen_size.y * 0.35) # Slight offset right
	enemy.position = e_pos
	enemy.set_origin(e_pos)
	enemy.set_origin(e_pos)
	# Initial facing handled by scale in perspective update, but set default here
	# enemy.scale.x = -1 # Disabled for 8-way sprites
	add_child(enemy)

	
	# UI Layer
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# HUD (Keeping existing HUD for energy/status, but ignoring HP labels on it)
	hud = load("res://scenes/ui/HUD.tscn").instantiate()
	ui_layer.add_child(hud)
	
	# Victory Screen
	var victory_screen = load("res://scenes/ui/VictoryScreen.tscn").instantiate()
	add_child(victory_screen)
	victory_screen.continue_pressed.connect(_on_victory_continue)
	set_meta("victory_screen", victory_screen)
	
	# Swipe Input
	swipe_input = SwipeInputSrc.new()
	ui_layer.add_child(swipe_input)
	
	# Defense Game
	defense_game = DefenseGameSrc.new()
	defense_game.visible = false
	ui_layer.add_child(defense_game)
	defense_game.succeeded.connect(_on_defense_success)
	defense_game.failed.connect(_on_defense_fail)
	
	# Pause Menu
	var pause_menu = load("res://scenes/ui/PauseMenu.gd").new()
	add_child(pause_menu)
	
	# Signals
	swipe_input.swipe_ended.connect(_on_swipe_ended)
	swipe_input.swipe_updated.connect(_on_swipe_updated)
	swipe_input.swipe_started.connect(_on_swipe_started)

func _start_battle():
	player_hp = PLAYER_HP_MAX
	enemy_hp = ENEMY_HP_MAX
	energy = 50
	
	_update_all_hp()
	hud.update_energy(energy)
	
	# Initial Player Facing: UP (Back to camera)
	if player:
		player.look_at_target(player.position + Vector2.UP * 100)
	
	_start_player_turn()

func _update_all_hp():
	# Update both HUD and Character labels
	hud.update_health(player_hp, PLAYER_HP_MAX, enemy_hp, ENEMY_HP_MAX)
	if player: player.update_hp(player_hp, PLAYER_HP_MAX)
	if enemy: enemy.update_hp(enemy_hp, ENEMY_HP_MAX)

func _process(_delta):
	_process_perspective()
	
	# Enemy Tracking
	if enemy and player and is_instance_valid(enemy) and is_instance_valid(player):
		# Only track if not attacking (simple check)
		# Or always track? Let's always track for now to satisfy request
		enemy.look_at_target(player.position)
	
	# Sandevistan Input
	if Input.is_key_pressed(KEY_Q) and not is_sandevistan and current_turn == "Player" and energy >= 100:
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


func _process_perspective():
	# Fake perspective scaling based on Y position
	var horizon_y = 200.0
	var bottom_y = 1080.0
	var min_scale = 0.5
	var max_scale = 1.2 # Slightly larger in front
	
	var chars = [player, enemy]
	for c in chars:
		if not c or not is_instance_valid(c): continue
		var t = clamp((c.position.y - horizon_y) / (bottom_y - horizon_y), 0.0, 1.0)
		# Non-linear easing for better depth feel
		t = pow(t, 0.5)
		var s = lerp(min_scale, max_scale, t)
		
		# Preserve facing direction (X sign)
		# We DO NOT want to flip scale for enemy anymore because we have 8-way sprites that handle direction.
		# if c == enemy: s *= -1
			
		c.scale = Vector2(s, s)

		# c.z_index = int(c.position.y) # Y-sort is enabled on Main, so Z-Index shouldn't be manual unless necessary

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
	if not is_sandevistan and combo_count > 0:
		current_step_duration = duration
		current_step_timer = get_tree().create_timer(duration)
		current_step_timer.timeout.connect(_on_swipe_timeout.bind(combo_count), CONNECT_ONE_SHOT)
	
	if is_sandevistan:
		# Fruit Ninja Mode
		swipe_input.show_target_circle(enemy.position + Vector2(0, -40))
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
			_handle_sandevistan_hit()

func _on_swipe_started(_pos):
	if is_sandevistan: return
	
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
	
	_update_all_hp()
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
	
	_update_all_hp()
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
	
	# Player returns, Enemy runs up (Vertical Attack)
	await player.return_to_origin()
	# Stop slightly short of the player to avoid overlap (Perspective offset)
	# Player is at Y=Bottom (~930). Enemy is running down.
	# Enemy should stop at Y ~ 800-850? 
	# Or rather, position.y should be less than player.y
	await enemy.run_to(player.position - Vector2(0, 120))
	
	await get_tree().create_timer(0.5).timeout
	_enemy_attack()

func _start_player_turn():
	current_turn = "Player"
	combo_count = 0
	hud.show_status("PLAYER TURN")
	# Run to slightly below enemy (Perspective: Higher Y is closer to screen, Lower Y is further)
	# Wait. Enemy is at Top (Deep in screen). Player is Bottom (Close to screen).
	# Player runs UP to Enemy.
	# Player Y should be > Enemy Y
	# Stop at enemy.position + Vector2(0, 120) (Below/Closer than enemy)
	await player.run_to(enemy.position + Vector2(0, 120))
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
	var dir_vec = end - start
	var length = dir_vec.length()
	var angle = dir_vec.angle()
	
	# Minimum visual length
	if length < 50: length = 50
	
	# Root pivot for easy transform
	var pivot = Node2D.new()
	pivot.position = start
	pivot.rotation = angle
	pivot.z_index = 100
	add_child(pivot)
	
	# Outer Glow (The "Color" of the slash)
	var glow = Line2D.new()
	glow.points = [Vector2.ZERO, Vector2(length * 1.2, 0)] # 1.2x to overshoot/pierce
	glow.width = 40.0
	glow.default_color = Color(0.1, 1.0, 1.0, 0.4) # Cyan Transparent
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_BOX
	pivot.add_child(glow)
	
	# Inner Core (Bright center)
	var core = Line2D.new()
	core.points = [Vector2.ZERO, Vector2(length * 1.1, 0)]
	core.width = 10.0
	core.default_color = Color(0.8, 1.0, 1.0, 1.0) # Almost White
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_BOX
	pivot.add_child(core)
	
	# Animation: Shoot out
	pivot.scale = Vector2(0.0, 1.0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Rapid extension (Shoot through)
	tween.tween_property(pivot, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Fade out
	tween.tween_property(pivot, "modulate:a", 0.0, 0.25).set_delay(0.1)
	
	tween.chain().tween_callback(pivot.queue_free)

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
