extends CharacterBody2D

class_name Character

var body_color: Color
var is_player: bool = false
var idle_tween: Tween # Store idle animation tween
var run_tween: Tween # Store run animation tween
var origin_pos: Vector2

# Sprite support
var sprite: Sprite2D
var weapon_sprite: Sprite2D # Composite sprite for weapon

@export var MAX_SPEED: float = 300.0
@export var ACCELERATION: float = 1500.0
@export var FRICTION: float = 1200.0

var manual_control: bool = true
var sprite_textures: Array = []
var last_dir: Vector2 = Vector2.DOWN

# Animation State
var run_down_textures: Array = []
var run_down_right_textures: Array = []
var run_right_textures: Array = []
var run_up_right_textures: Array = []
var run_up_textures: Array = []
var run_up_left_textures: Array = []
var run_left_textures: Array = []
var run_down_left_textures: Array = []
var anim_timer: float = 0.0

# Weapon Config Dictionary
# Maps direction Index (0-7) to Transform params:
# position, rotation (degrees), z_index (relative), flip_v (bool)

var weapon_config: Dictionary = {
	0: {"pos": Vector2(-12, -22), "rot": - 90.0, "z": 1, "flip_v": false}, # Left
	1: {"pos": Vector2(-10, -20), "rot": - 135.0, "z": 1, "flip_v": false}, # Down Left
	2: {"pos": Vector2(10, -20), "rot": 135.0, "z": 1, "flip_v": false}, # Down Right
	3: {"pos": Vector2(12, -18), "rot": 180.0, "z": 1, "flip_v": false}, # Down
	4: {"pos": Vector2(-10, -28), "rot": - 45.0, "z": - 1, "flip_v": true}, # Up Left (Behind)
	5: {"pos": Vector2(10, -28), "rot": - 45.0, "z": - 1, "flip_v": true}, # Up Right (Behind) - FIXED ROTATION
	6: {"pos": Vector2(0, -30), "rot": 0.0, "z": - 1, "flip_v": true}, # Up (Behind)
	7: {"pos": Vector2(12, -22), "rot": 0.0, "z": 1, "flip_v": false} # Right - FIXED ROTATION
}

# Jump Mechanics

const JUMP_VELOCITY = -350.0
const GRAVITY = 800.0
var z_axis: float = 0.0
var z_velocity: float = 0.0

var current_frame: int = 0

# UI
var hp_bg: ColorRect
var hp_fill: ColorRect

func set_origin(pos: Vector2):
	origin_pos = pos

func setup(color: Color, is_player_char: bool):
	body_color = color
	is_player = is_player_char
	
	_setup_hp_bar()
	
	# Try to load sprites
	_setup_sprites()
	
	# Setup composite weapon
	_setup_weapon()
	
	play_idle()

func _ready():
	_setup_inputs()

func _setup_inputs():
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		var ev = InputEventKey.new()
		ev.keycode = KEY_A
		InputMap.action_add_event("move_left", ev)
		
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		var ev = InputEventKey.new()
		ev.keycode = KEY_D
		InputMap.action_add_event("move_right", ev)
		
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
		var ev = InputEventKey.new()
		ev.keycode = KEY_W
		InputMap.action_add_event("move_up", ev)
		
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
		var ev = InputEventKey.new()
		ev.keycode = KEY_S
		InputMap.action_add_event("move_down", ev)


func _setup_hp_bar():
	# Disable overhead bar for player (uses HUD now)
	if is_player: return
	
	hp_bg = ColorRect.new()
	hp_bg.size = Vector2(100, 10)
	hp_bg.position = Vector2(-50, -130) # Above head
	hp_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	hp_bg.z_index = 10
	add_child(hp_bg)
	
	hp_fill = ColorRect.new()
	hp_fill.size = Vector2(100, 10)
	hp_fill.position = Vector2(-50, -130)
	hp_fill.color = Color(0.2, 1.0, 0.2) if is_player else Color(1.0, 0.2, 0.2)
	hp_fill.z_index = 11
	add_child(hp_fill)

func update_hp(val, max_val):
	if hp_fill:
		var pct = float(val) / float(max_val)
		var target_width = 100.0 * pct
		
		# Animate width
		var t = create_tween()
		t.tween_property(hp_fill, "size:x", target_width, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Color logic
		var target_color = Color(0.2, 1.0, 0.2) if is_player else Color(1.0, 0.2, 0.2)
		if pct < 0.3:
			target_color = Color(1.0, 0.0, 0.0) # Critical red
			# Flash
			var flash = create_tween().set_loops(3)
			flash.tween_property(hp_fill, "modulate", Color.WHITE, 0.1)
			flash.tween_property(hp_fill, "modulate", target_color, 0.1)
			
		hp_fill.color = target_color

func play_idle():
	if idle_tween and idle_tween.is_valid():
		idle_tween.kill()

func run_to(target_pos: Vector2, duration: float = 1.0):
	# STOP all competing animations
	if idle_tween and idle_tween.is_valid(): idle_tween.kill()
	if run_tween and run_tween.is_valid(): run_tween.kill()
	
	# Determine Run Direction for Sprite
	var dir = (target_pos - position).normalized()
	if dir != Vector2.ZERO:
		_update_sprite_direction(dir, 0.1) # Force frame update
	
	# MOVEMENT TWEEN (XY Support for 2.5D)
	var move_tween = create_tween()
	move_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_LINEAR)
	
	await move_tween.finished
	
	play_idle()

func return_to_origin(duration: float = 1.0):
	await run_to(origin_pos, duration)

func play_attack_pose(is_fast: bool = false):
	if idle_tween and idle_tween.is_valid(): idle_tween.kill()
	
	var dir = 1.0 if is_player else -1.0
	var speed = 0.5 if is_fast else 1.0
	var tween = create_tween()
	var start_pos = position
	
	# Simple Sprite Lunge
	var lunge_offset = Vector2(15 * dir, 0)
	tween.tween_property(self, "position", start_pos + lunge_offset, 0.08 * speed).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_property(self, "position", start_pos, 0.3 * speed)
	
	tween.tween_callback(play_idle)
	await tween.finished

func _reset_pose():
	pass

func play_sword_swing(_is_fast: bool = false):
	# Animate composite weapon if needed, or just let body animation carry it
	# For now, we can perhaps rotate the weapon sprite independently?
	pass

func play_lunge(target_pos: Vector2):
	var start = position
	var end = target_pos + Vector2(50 if scale.x > 0 else -50, 0)
	var tween = create_tween()
	tween.tween_property(self, "position", end, 0.1).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "position", start, 0.4).set_trans(Tween.TRANS_ELASTIC)

func play_death():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation", PI / 2, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
	await tween.finished

func _setup_sprites():
	var file_names = [
		"uploaded_image_0_1765714206009.png",
		"uploaded_image_1_1765714206009.png",
		"uploaded_image_2_1765714206009.png",
		"uploaded_image_3_1765714206009.png",
		"uploaded_image_4_1765714206009.png",
		"uploaded_image_0_1765714411778.png",
		"uploaded_image_1_1765714411778.png",
		"uploaded_image_2_1765714411778.png"
	]
	
	sprite_textures.clear()
	var _loaded_count = 0
	
	for f in file_names:
		var tex = null
		var path = "res://assets/sprites/" + f
		var _abs_path = ProjectSettings.globalize_path(path)
		
		if ResourceLoader.exists(path):
			tex = load(path)
			
		if not tex and FileAccess.file_exists(path):
			var img = Image.new()
			var err = img.load(path)
			if err == OK:
				tex = ImageTexture.create_from_image(img)
			else:
				print("Failed to load image invalid format: ", path)
				
		if tex:
			sprite_textures.append(tex)
			_loaded_count += 1
		else:
			sprite_textures.append(null)

	# Load Run Animations
	var load_anim = func(prefix):
		var frames = []
		for i in range(6):
			var p = "res://assets/sprites/" + prefix + "/" + prefix + "_" + str(i) + ".png"
			var t = null
			if ResourceLoader.exists(p): t = load(p)
			elif FileAccess.file_exists(p):
				var i_load = Image.new()
				if i_load.load(p) == OK: t = ImageTexture.create_from_image(i_load)
			if t: frames.append(t)
			else: print("Missing frame: " + p)
		return frames

	run_down_textures = load_anim.call("run_down")
	run_down_right_textures = load_anim.call("run_down_right")
	run_right_textures = load_anim.call("run_right")
	run_up_right_textures = load_anim.call("run_up_right")
	run_up_textures = load_anim.call("run_up")
	run_up_left_textures = load_anim.call("run_up_left")
	run_left_textures = load_anim.call("run_left")
	run_down_left_textures = load_anim.call("run_down_left")

	# Create or update sprite
	if not sprite:
		sprite = Sprite2D.new()
		sprite.position = Vector2(0, -30)
		sprite.scale = Vector2(3, 3)
		add_child(sprite)
	
	# Find first valid texture for default
	for t in sprite_textures:
		if t:
			sprite.texture = t
			break

func _setup_weapon():
	if not weapon_sprite:
		weapon_sprite = Sprite2D.new()
		weapon_sprite.name = "WeaponSprite"
		# Default scale for pixel perfect match
		weapon_sprite.scale = Vector2(0.14, 0.14)
		add_child(weapon_sprite)
		
	# Load Weapon Texture
	var path = "res://assets/sprites/pixelart_cybersword.png"
	var tex = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img = Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
			
	if tex:
		weapon_sprite.texture = tex
		# Pivot Logic: Center of rotation should be handle.
		# Assuming sword is vertical in image, handle is at bottom.
		# If texture size is e.g. 64x64, center is 32,32. Handle at 32, 60?
		# Offset moves the texture relative to Node position (Pivot).
		# To put pivot at handle (bottom), we shift texture UP (-y).
		var size = tex.get_size()
		weapon_sprite.offset = Vector2(0, -size.y / 2.0)
		
	# Set Neon Glow
	equip_weapon(Color(1.5, 1.2, 2.0)) # Purple/Blue glow

func equip_weapon(glow_color: Color):
	if weapon_sprite:
		# Modulate > 1.0 creates Glow in WorldEnvironment (if Glow enabled)
		weapon_sprite.modulate = glow_color

func _physics_process(delta):
	if is_player and manual_control:
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
		# Movement Physics
		if input_dir != Vector2.ZERO:
			velocity = velocity.move_toward(input_dir * MAX_SPEED, ACCELERATION * delta)
			last_dir = input_dir
			_update_sprite_direction(input_dir, delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
			_update_sprite_direction(last_dir, 0.0)
			
		move_and_slide()
			
		# Jump Mechanic
		if Input.is_action_just_pressed("ui_accept") and z_axis >= 0:
			z_velocity = JUMP_VELOCITY
			
		# Apply Gravity and Z-Axis Movement
		# Apex Hang: Reduce gravity when near the top of the jump for a smooth stop
		var applied_gravity = GRAVITY
		if abs(z_velocity) < 100:
			applied_gravity *= 0.5
			
		z_velocity += applied_gravity * delta
		z_axis += z_velocity * delta
		
		# Floor Collision
		if z_axis >= 0:
			z_axis = 0
			z_velocity = 0
			
		# Apply Visual Offset to Sprite
		if sprite:
			sprite.position.y = -30 + z_axis
			# Sync weapon visual y with jump
			if weapon_sprite:
				# Use local variable for base Y as determined by direction config
				pass

func _update_sprite_direction(dir: Vector2, delta: float = 0.0):
	if not sprite or sprite_textures.size() == 0: return
	
	# 8-Way Logic
	var angle = rad_to_deg(dir.angle())
	if angle < 0: angle += 360
	
	var index = 0
	
	if angle >= 337.5 or angle < 22.5:
		index = 7 # Right
	elif angle >= 22.5 and angle < 67.5:
		index = 2 # Down Right
	elif angle >= 67.5 and angle < 112.5:
		index = 3 # Down
	elif angle >= 112.5 and angle < 157.5:
		index = 1 # Down Left
	elif angle >= 157.5 and angle < 202.5:
		index = 0 # Left
	elif angle >= 202.5 and angle < 247.5:
		index = 4 # Up Left
	elif angle >= 247.5 and angle < 292.5:
		index = 6 # Up
	elif angle >= 292.5 and angle < 337.5:
		index = 5 # Up Right
	
	# Animation Update Helper (same as before)
	var update_anim = func(textures: Array):
		if delta > 0.0 and textures.size() > 0:
			anim_timer += delta
			if anim_timer >= 0.1: # 10 FPS
				anim_timer = 0.0
				current_frame = (current_frame + 1) % textures.size()
			sprite.texture = textures[current_frame]
			return true
		return false

	var is_moving = false
	if index == 3 and update_anim.call(run_down_textures): is_moving = true
	elif index == 2 and update_anim.call(run_down_right_textures): is_moving = true
	elif index == 7 and update_anim.call(run_right_textures): is_moving = true
	elif index == 5 and update_anim.call(run_up_right_textures): is_moving = true
	elif index == 6 and update_anim.call(run_up_textures): is_moving = true
	elif index == 4 and update_anim.call(run_up_left_textures): is_moving = true
	elif index == 0 and update_anim.call(run_left_textures): is_moving = true
	elif index == 1 and update_anim.call(run_down_left_textures): is_moving = true
	
	if not is_moving:
		# Static fallback
		if index < sprite_textures.size() and sprite_textures[index] != null:
			sprite.texture = sprite_textures[index]
		elif sprite_textures.size() > 0 and sprite_textures[0] != null:
			sprite.texture = sprite_textures[0]

	# Sync Weapon
	if weapon_sprite and weapon_config.has(index):
		var cfg = weapon_config[index]
		weapon_sprite.position = cfg["pos"] + Vector2(0, z_axis) # Add Jump offset
		weapon_sprite.rotation_degrees = cfg["rot"]
		weapon_sprite.z_index = cfg["z"]
		weapon_sprite.flip_v = cfg["flip_v"]

func look_at_target(target_pos: Vector2):
	var dir = (target_pos - position).normalized()
	if dir != Vector2.ZERO:
		last_dir = dir
		_update_sprite_direction(dir, 0.0)
