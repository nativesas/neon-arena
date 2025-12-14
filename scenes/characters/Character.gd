extends Node2D

class_name Character

var body_color: Color
var is_player: bool = false
var sword_node: Node2D
var sword_tween: Tween # Store sword animation tween
var idle_tween: Tween # Store idle animation tween
var run_tween: Tween # Store run animation tween
var origin_pos: Vector2

# Bone references
var torso: Node2D
var head: Node2D
var upper_arm_r: Node2D
var upper_arm_l: Node2D
var forearm_r: Node2D
var forearm_l: Node2D
var thigh_r: Node2D
var thigh_l: Node2D
var shin_r: Node2D
var shin_l: Node2D

func set_origin(pos: Vector2):
	origin_pos = pos

func setup(color: Color, is_player_char: bool):
	body_color = color
	is_player = is_player_char
	_create_stick_figure()
	if is_player:
		_add_hat("TopHat", Color(1.0, 0.8, 0.2))
	else:
		_add_hat("Cap", Color(0.2, 1.0, 0.4))
	
	_add_sword()
	play_idle()

func play_idle():
	# Stop existing idle tween if valid
	if idle_tween and idle_tween.is_valid():
		idle_tween.kill()
		
	# Simple breathing animation using torso bone
	if torso:
		idle_tween = create_tween().set_loops()
		idle_tween.tween_property(torso, "rotation", 0.05, 1.0).set_trans(Tween.TRANS_SINE)
		idle_tween.tween_property(torso, "rotation", -0.05, 1.0).set_trans(Tween.TRANS_SINE)

func run_to(target_pos: Vector2, duration: float = 1.0):
	# STOP all competing animations
	if idle_tween and idle_tween.is_valid(): idle_tween.kill()
	if run_tween and run_tween.is_valid(): run_tween.kill()
	
	# MOVEMENT TWEEN
	var move_tween = create_tween()
	move_tween.tween_property(self, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_LINEAR)
	
	# Determine Run Direction relative to Facings
	# If running towards facing direction: Forward (1). If retreating: Backward (-1).
	var global_dir = sign(target_pos.x - position.x)
	var local_dir = global_dir * sign(scale.x) if scale.x != 0 else global_dir
	# If local_dir is 0 (no movement), default to 1
	if local_dir == 0: local_dir = 1
	
	# RUN CYCLE (Grounded Jog)
	if torso and thigh_r and thigh_l:
		run_tween = create_tween().set_loops()
		run_tween.set_parallel(true)
		
		# DYNAMIC BODY LEAN (Lean into movement)
		# 0.25 rad (approx 15 deg) lean.
		run_tween.tween_property(torso, "rotation", 0.25 * local_dir, 0.1)
		
		var cycle_time = 0.4 # Fast steps
		var half_cycle = cycle_time / 2.0
		
		# Reduced Amplitudes for "Normal Run"
		# Thighs: +/- 0.5 rad (approx 28 deg)
		# Shins: 0.0 to 1.0 rad
		# Arms: +/- 0.5 rad
		
		# STEP 1: Right Leg Back (Push), Left Leg Fwd (Contact)
		# NOTE: Cycles assume Forward running. If local_dir is -1 (Backward), we might want to reverse logic?
		# For now, let's keep standard cycle, legs will just look like 'moonwalking' if retreating.
		# Ideally legs should cycle 'backwards' if moving backwards, but 'return_to_origin' slide looks cleaner.
		# Let's assume standard forward cycle for 'run_to'.
		
		# Right Leg (Pushing Back)
		run_tween.tween_property(thigh_r, "rotation", -0.5, half_cycle).set_trans(Tween.TRANS_SINE)
		run_tween.tween_property(shin_r, "rotation", 1.0, half_cycle).set_trans(Tween.TRANS_SINE) # Curl
		
		# Left Leg (Reaching Forward)
		run_tween.tween_property(thigh_l, "rotation", 0.6, half_cycle).set_trans(Tween.TRANS_SINE)
		run_tween.tween_property(shin_l, "rotation", 0.0, half_cycle).set_trans(Tween.TRANS_SINE) # Straight
		
		# Arms
		run_tween.tween_property(upper_arm_r, "rotation", 0.5, half_cycle)
		run_tween.tween_property(upper_arm_l, "rotation", -0.5, half_cycle)
		
		# Bobbing (Subtle)
		run_tween.tween_property(self, "position:y", origin_pos.y + 4, half_cycle * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		run_tween.chain().tween_property(self, "position:y", origin_pos.y, half_cycle * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# STEP 2: Switch
		run_tween.chain().set_parallel(true)
		
		# Right Leg (Reaching Forward)
		run_tween.tween_property(thigh_r, "rotation", 0.6, half_cycle).set_trans(Tween.TRANS_SINE)
		run_tween.tween_property(shin_r, "rotation", 0.0, half_cycle).set_trans(Tween.TRANS_SINE) # Straight
		
		# Left Leg (Pushing Back)
		run_tween.tween_property(thigh_l, "rotation", -0.5, half_cycle).set_trans(Tween.TRANS_SINE)
		run_tween.tween_property(shin_l, "rotation", 1.0, half_cycle).set_trans(Tween.TRANS_SINE) # Curl
		
		# Arms
		run_tween.tween_property(upper_arm_r, "rotation", -0.5, half_cycle)
		run_tween.tween_property(upper_arm_l, "rotation", 0.5, half_cycle)
		
		# Bobbing
		run_tween.tween_property(self, "position:y", origin_pos.y + 4, half_cycle * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		run_tween.chain().tween_property(self, "position:y", origin_pos.y, half_cycle * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	await move_tween.finished
	
	if run_tween and run_tween.is_valid(): run_tween.kill()
	_reset_pose()
	position.y = origin_pos.y
	play_idle()

func return_to_origin(duration: float = 1.0):
	# Just use run_to logic, it handles direction calculation now
	await run_to(origin_pos, duration)

func play_attack_pose(is_fast: bool = false):
	if idle_tween and idle_tween.is_valid(): idle_tween.kill()
	
	var dir = 1.0 if is_player else -1.0
	var speed = 0.5 if is_fast else 1.0
	var tween = create_tween()
	var start_pos = position
	
	# GROUNDED, SNAPPY ATTACK
	
	# PHASE 1: WINDUP (Very Minimal)
	tween.set_parallel(true)
	# Slight lean back
	tween.tween_property(torso, "rotation", -0.2 * dir, 0.15 * speed)
	# Arm ready
	tween.tween_property(upper_arm_r, "rotation", 1.0 * dir, 0.15 * speed)
	if forearm_r: tween.tween_property(forearm_r, "rotation", 0.3 * dir, 0.15 * speed)
	# Stability stance
	if thigh_r: tween.tween_property(thigh_r, "rotation", 0.2 * dir, 0.15 * speed)
	if thigh_l: tween.tween_property(thigh_l, "rotation", -0.2 * dir, 0.15 * speed)
	
	# PHASE 2: STRIKE (Fast Lunge)
	tween.chain().set_parallel(true)
	# Short step insteda of huge jump (15px)
	tween.tween_property(self, "position:x", start_pos.x + (15 * dir), 0.08 * speed).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(torso, "rotation", 0.4 * dir, 0.08 * speed)
	
	# Sword swing
	tween.tween_property(upper_arm_r, "rotation", -1.8 * dir, 0.08 * speed).set_trans(Tween.TRANS_CUBIC)
	if forearm_r: tween.tween_property(forearm_r, "rotation", -0.2 * dir, 0.08 * speed)
	
	# Legs lunge slightly
	if thigh_r: tween.tween_property(thigh_r, "rotation", -0.3 * dir, 0.08 * speed)
	if thigh_l: tween.tween_property(thigh_l, "rotation", 0.3 * dir, 0.08 * speed)
	
	# PHASE 3: RECOVERY
	tween.chain().set_parallel(true)
	tween.tween_property(self, "position", start_pos, 0.3 * speed)
	tween.tween_property(torso, "rotation", 0.0, 0.3 * speed)
	tween.tween_property(upper_arm_r, "rotation", 0.0, 0.3 * speed)
	
	tween.tween_callback(func():
		_reset_pose()
		play_idle()
	)
	
	await tween.finished

func _reset_pose():
	# Helper to reset to neutral T-pose/Idle
	if torso: torso.rotation = 0
	if head: head.rotation = 0; head.position.y = -30
	if thigh_r: thigh_r.rotation = 0
	if thigh_l: thigh_l.rotation = 0
	if shin_r: shin_r.rotation = 0
	if shin_l: shin_l.rotation = 0
	if upper_arm_r: upper_arm_r.rotation = 0
	if upper_arm_l: upper_arm_l.rotation = 0
	if forearm_r: forearm_r.rotation = 0
	if forearm_l: forearm_l.rotation = 0

func play_sword_swing(is_fast: bool = false):
	# Kill previous tweens on sword_node to prevent conflict
	if sword_tween and sword_tween.is_valid():
		sword_tween.kill()
		
	var tween = create_tween()
	sword_tween = tween
	
	var start_rot = 0.0
	var dir = 1.0 if is_player else -1.0
	
	# Speed multiplier: Sandevistan needs to be ignored_time_scale equivalent or just very fast
	# If time_scale is 0.3, we want animation to look normal (1.0). So we multiply duration by 0.3?
	# Or if we want it "fast", we make it 0.05s.
	var speed_mult = 0.2 if is_fast else 1.0
	
	# Dramtic Windup (Goes back ~135 degrees)
	var windup_angle = start_rot - (PI * 0.75 * dir)
	tween.tween_property(sword_node, "rotation", windup_angle, 0.1 * speed_mult).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Massive Swing (Cuts through ~270 degrees)
	var swing_angle = start_rot + (PI * 0.75 * dir)
	tween.tween_property(sword_node, "rotation", swing_angle, 0.15 * speed_mult).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Return
	tween.tween_property(sword_node, "rotation", start_rot, 0.3 * speed_mult).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Return
	tween.tween_property(sword_node, "rotation", start_rot, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func play_lunge(target_pos: Vector2):
	# Deprecated/Legacy lunge (kept for compatibility or small hops)
	var start = position
	var end = target_pos + Vector2(50 if scale.x > 0 else -50, 0)
	var tween = create_tween()
	tween.tween_property(self, "position", end, 0.1).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(self, "position", start, 0.4).set_trans(Tween.TRANS_ELASTIC)

func play_death():
	# Fall over and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Rotate to fall over
	tween.tween_property(self, "rotation", PI / 2, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Sink down
	tween.tween_property(self, "position:y", position.y + 50, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.8).set_delay(0.2)
	
	await tween.finished

func _create_stick_figure():
	# Skeletal bone system - each joint can rotate independently
	# Torso bone (root of upper body)
	var torso_node = Node2D.new()
	torso_node.position = Vector2(0, -30)
	add_child(torso_node)
	var torso_line = Line2D.new()
	torso_line.width = 6
	torso_line.default_color = body_color
	torso_line.add_point(Vector2(0, 60)) # Hip - extended to connect with legs
	torso_line.add_point(Vector2(0, -30)) # Shoulder
	torso_node.add_child(torso_line)
	self.torso = torso_node
	
	# Head bone (child of torso)
	var head_node = Node2D.new()
	head_node.position = Vector2(0, -30)
	torso_node.add_child(head_node)
	var head_circle = Line2D.new()
	head_circle.width = 6
	head_circle.default_color = body_color
	_create_circle(head_circle, 15)
	head_circle.position = Vector2(0, -20)
	head_node.add_child(head_circle)
	self.head = head_node
	
	# Right arm (upper arm bone)
	var upper_arm_r_node = Node2D.new()
	upper_arm_r_node.position = Vector2(0, -30) # Shoulder
	torso_node.add_child(upper_arm_r_node)
	var upper_arm_r_line = Line2D.new()
	upper_arm_r_line.width = 6
	upper_arm_r_line.default_color = body_color
	upper_arm_r_line.add_point(Vector2(0, 0))
	upper_arm_r_line.add_point(Vector2(20, 30))
	upper_arm_r_node.add_child(upper_arm_r_line)
	self.upper_arm_r = upper_arm_r_node
	
	# Right forearm (child of upper arm)
	var forearm_r_node = Node2D.new()
	forearm_r_node.position = Vector2(20, 30) # Elbow
	upper_arm_r_node.add_child(forearm_r_node)
	var forearm_r_line = Line2D.new()
	forearm_r_line.width = 6
	forearm_r_line.default_color = body_color
	forearm_r_line.add_point(Vector2(0, 0))
	forearm_r_line.add_point(Vector2(0, 30))
	forearm_r_node.add_child(forearm_r_line)
	self.forearm_r = forearm_r_node
	
	# Left arm (upper arm bone)
	var upper_arm_l_node = Node2D.new()
	upper_arm_l_node.position = Vector2(0, -30) # Shoulder
	torso_node.add_child(upper_arm_l_node)
	var upper_arm_l_line = Line2D.new()
	upper_arm_l_line.width = 6
	upper_arm_l_line.default_color = body_color
	upper_arm_l_line.add_point(Vector2(0, 0))
	upper_arm_l_line.add_point(Vector2(-20, 30))
	upper_arm_l_node.add_child(upper_arm_l_line)
	self.upper_arm_l = upper_arm_l_node
	
	# Left forearm
	var forearm_l_node = Node2D.new()
	forearm_l_node.position = Vector2(-20, 30)
	upper_arm_l_node.add_child(forearm_l_node)
	var forearm_l_line = Line2D.new()
	forearm_l_line.width = 6
	forearm_l_line.default_color = body_color
	forearm_l_line.add_point(Vector2(0, 0))
	forearm_l_line.add_point(Vector2(0, 30))
	forearm_l_node.add_child(forearm_l_line)
	self.forearm_l = forearm_l_node
	
	# Right leg (thigh)
	var thigh_r_node = Node2D.new()
	thigh_r_node.position = Vector2(0, 60) # Hip (Local to Torso)
	torso_node.add_child(thigh_r_node) # Attached to Torso
	var thigh_r_line = Line2D.new()
	thigh_r_line.width = 6
	thigh_r_line.default_color = body_color
	thigh_r_line.add_point(Vector2(0, 0))
	thigh_r_line.add_point(Vector2(10, 25))
	thigh_r_node.add_child(thigh_r_line)
	self.thigh_r = thigh_r_node
	
	# Right shin
	var shin_r_node = Node2D.new()
	shin_r_node.position = Vector2(10, 25)
	thigh_r_node.add_child(shin_r_node)
	var shin_r_line = Line2D.new()
	shin_r_line.width = 6
	shin_r_line.default_color = body_color
	shin_r_line.add_point(Vector2(0, 0))
	shin_r_line.add_point(Vector2(5, 25))
	shin_r_node.add_child(shin_r_line)
	self.shin_r = shin_r_node
	
	# Left leg (thigh)
	var thigh_l_node = Node2D.new()
	thigh_l_node.position = Vector2(0, 60) # Hip (Local to Torso)
	torso_node.add_child(thigh_l_node) # Attached to Torso
	var thigh_l_line = Line2D.new()
	thigh_l_line.width = 6
	thigh_l_line.default_color = body_color
	thigh_l_line.add_point(Vector2(0, 0))
	thigh_l_line.add_point(Vector2(-10, 25))
	thigh_l_node.add_child(thigh_l_line)
	self.thigh_l = thigh_l_node
	
	# Left shin
	var shin_l_node = Node2D.new()
	shin_l_node.position = Vector2(-10, 25)
	thigh_l_node.add_child(shin_l_node)
	var shin_l_line = Line2D.new()
	shin_l_line.width = 6
	shin_l_line.default_color = body_color
	shin_l_line.add_point(Vector2(0, 0))
	shin_l_line.add_point(Vector2(-5, 25))
	shin_l_node.add_child(shin_l_line)
	self.shin_l = shin_l_node

func _create_circle(line, radius):
	for i in range(17):
		var angle = i * TAU / 16.0
		line.add_point(Vector2(cos(angle), sin(angle)) * radius)

func _add_hat(type, color):
	# Head is now a member variable
	var hat = Node2D.new()
	hat.position = Vector2(0, -35)
	head.add_child(hat)
	
	var line = Line2D.new()
	line.default_color = color
	line.width = 4
	hat.add_child(line)
	
	if type == "TopHat":
		line.add_point(Vector2(-20, 0))
		line.add_point(Vector2(20, 0))
		var sub = Line2D.new()
		sub.default_color = color; sub.width = 4
		sub.add_point(Vector2(12, 0)); sub.add_point(Vector2(12, -30))
		sub.add_point(Vector2(-12, -30)); sub.add_point(Vector2(-12, 0))
		hat.add_child(sub)
	elif type == "Cap":
		for i in range(9):
			var a = PI + (i * PI / 8.0)
			line.add_point(Vector2(cos(a), sin(a) * 0.8) * 16)
		line.add_point(Vector2(16, 0))
		line.add_point(Vector2(28, 5))

func _add_sword():
	# Attach sword to right forearm (member variable)
	sword_node = Node2D.new()
	sword_node.position = Vector2(0, 30) # Hand position (end of forearm)
	forearm_r.add_child(sword_node)
	
	var blade = Line2D.new()
	blade.points = [Vector2(0, 0), Vector2(10, -50)]
	blade.default_color = Color(0.8, 1.0, 1.0)
	blade.width = 3
	sword_node.add_child(blade)
	
	var hilt = Line2D.new()
	hilt.points = [Vector2(-5, -5), Vector2(8, 2)]
	hilt.default_color = Color.GRAY
	hilt.width = 4
	sword_node.add_child(hilt)
