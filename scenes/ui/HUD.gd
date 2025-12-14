extends CanvasLayer

class_name HUD

# UI Elements
var hp_label_player: Label
var hp_label_enemy: Label
var status_label: Label
var energy_bar: ColorRect
var sandevistan_hint: Label

# New Graphical HP Bar Elements
var hp_bar_container: Control
var hp_bar_fill: ColorRect
var hp_segments_holder: Control

# Config
const ENERGY_BAR_WIDTH = 200.0
const HP_BAR_WIDTH = 300.0
const HP_BAR_HEIGHT = 20.0

func _ready():
	_setup_ui()

func _setup_ui():
	# Allow for re-setup if needed
	if status_label: return
	
	# Status Label (Center)
	status_label = _create_label(Vector2(0, 150), "", Color.YELLOW)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size = Vector2(1152, 50) # Approx screen width
	
	# Energy Bar (Top Left - keep close to Sandevistan hint)
	var energy_bg = ColorRect.new()
	energy_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	energy_bg.size = Vector2(ENERGY_BAR_WIDTH, 10)
	energy_bg.position = Vector2(20, 50)
	add_child(energy_bg)
	
	energy_bar = ColorRect.new()
	energy_bar.color = Color(1.0, 0.5, 0.0) # Orange
	energy_bar.size = Vector2(0, 10)
	energy_bar.position = Vector2(20, 50)
	add_child(energy_bar)
	
	sandevistan_hint = Label.new()
	sandevistan_hint.text = "SANDEVISTAN [Q]"
	sandevistan_hint.position = Vector2(20, 30)
	sandevistan_hint.scale = Vector2(0.8, 0.8)
	add_child(sandevistan_hint)
	
	# --- PLAYER HP BAR (Bottom Left) ---
	_setup_player_hp_bar()
	
	# Optional: Enemy text label kept for now? Or remove?
	# User asked for Player HP at bottom left.
	# Let's keep enemy label minimal or remove if needed. 
	# Keeping hp_label_enemy for debugging/clarity for now.
	hp_label_enemy = Label.new()
	hp_label_enemy.position = Vector2(900, 50)
	hp_label_enemy.modulate = Color(1.0, 0.2, 0.4)
	add_child(hp_label_enemy)

func _setup_player_hp_bar():
	var screen_h = 1080.0 # Virtual resolution height
	var padding = 30.0
	var pos = Vector2(padding, screen_h - padding - HP_BAR_HEIGHT)
	
	hp_bar_container = Control.new()
	hp_bar_container.position = pos
	add_child(hp_bar_container)
	
	# HP Label above bar
	var hp_text = Label.new()
	hp_text.text = "HP"
	hp_text.position = Vector2(0, -25)
	hp_text.modulate = Color.CYAN
	hp_bar_container.add_child(hp_text)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.8)
	bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_container.add_child(bg)
	
	# Fill (Green/Cyan)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.0, 1.0, 0.8) # Cyan/Greenish
	hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_container.add_child(hp_bar_fill)
	
	# Segments (Lines every 10%)
	hp_segments_holder = Control.new()
	hp_bar_container.add_child(hp_segments_holder)
	
	for i in range(1, 10): # 10% to 90%
		var line = ColorRect.new()
		line.color = Color.BLACK
		line.size = Vector2(2, HP_BAR_HEIGHT)
		line.position = Vector2((HP_BAR_WIDTH * 0.1 * i) - 1, 0) # Centered on the %
		hp_segments_holder.add_child(line)
		
	# Border (Optional, maybe just a frame?)
	
func update_health(player_hp, max_player_hp, enemy_hp, _max_enemy_hp):
	# Update Player Bar
	if hp_bar_fill:
		var pct = clamp(float(player_hp) / float(max_player_hp), 0.0, 1.0)
		hp_bar_fill.size.x = HP_BAR_WIDTH * pct
		
		# Color logic (Critical)
		if pct < 0.3:
			hp_bar_fill.color = Color(1.0, 0.2, 0.2) # Red
		else:
			hp_bar_fill.color = Color(0.0, 1.0, 0.8) # Cyan
			
	# Update Enemy Label
	if hp_label_enemy:
		hp_label_enemy.text = "ENEMY HP: " + str(int(enemy_hp))

func update_energy(amount):
	if energy_bar:
		energy_bar.size.x = (amount / 100.0) * ENERGY_BAR_WIDTH

func show_status(text, color = Color.YELLOW):
	if status_label:
		status_label.text = text
		status_label.modulate = color
		status_label.modulate.a = 1.0
		
		var tween = create_tween()
		tween.tween_property(status_label, "modulate:a", 0.0, 2.0)

func pop_text(pos, text, color = Color.WHITE):
	var l = Label.new()
	l.text = text
	l.position = pos + Vector2(randf_range(-20, 20), -50)
	l.modulate = color
	add_child(l)
	
	var tween = create_tween()
	tween.tween_property(l, "position:y", l.position.y - 50, 0.5)
	tween.tween_property(l, "modulate:a", 0.0, 0.5)
	tween.tween_callback(l.queue_free)

func _create_label(pos, text, color):
	var l = Label.new()
	l.position = pos
	l.text = text
	l.modulate = color
	l.scale = Vector2(1.5, 1.5)
	add_child(l)
	return l
