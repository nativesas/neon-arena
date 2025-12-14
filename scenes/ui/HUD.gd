extends CanvasLayer

class_name HUD

# UI Elements
var hp_label_player: Label
var hp_label_enemy: Label
var status_label: Label
var energy_bar: ColorRect
var energy_bar_bg: ColorRect
var sandevistan_hint: Label

# Config
const BAR_WIDTH = 200.0

func _ready():
	_setup_ui()

func _setup_ui():
	# Allow for re-setup if needed, or initial setup
	if hp_label_player: return

	hp_label_player = _create_label(Vector2(50, 50), "PLAYER", Color(0.2, 0.8, 1.0))
	hp_label_enemy = _create_label(Vector2(900, 50), "ENEMY", Color(1.0, 0.2, 0.4))
	
	status_label = _create_label(Vector2(0, 150), "", Color.YELLOW)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size = Vector2(1152, 50) # Approx screen width
	
	# Energy Bar
	energy_bar_bg = ColorRect.new()
	energy_bar_bg.color = Color(0.2, 0.2, 0.2)
	energy_bar_bg.size = Vector2(BAR_WIDTH, 20)
	energy_bar_bg.position = Vector2(50, 100)
	add_child(energy_bar_bg)
	
	energy_bar = ColorRect.new()
	energy_bar.color = Color(1.0, 0.5, 0.0) # Orange
	energy_bar.size = Vector2(0, 20)
	energy_bar.position = Vector2(50, 100)
	add_child(energy_bar)
	
	sandevistan_hint = Label.new()
	sandevistan_hint.text = "SANDEVISTAN [SPACE]"
	sandevistan_hint.position = Vector2(50, 80)
	sandevistan_hint.scale = Vector2(0.8, 0.8)
	add_child(sandevistan_hint)

func update_health(player_hp, enemy_hp):
	if hp_label_player: hp_label_player.text = "HP: " + str(int(player_hp))
	if hp_label_enemy: hp_label_enemy.text = "HP: " + str(int(enemy_hp))

func update_energy(amount):
	if energy_bar:
		energy_bar.size.x = (amount / 100.0) * BAR_WIDTH

func show_status(text, color = Color.YELLOW):
	if status_label:
		status_label.text = text
		status_label.modulate = color
		status_label.modulate.a = 1.0
		
		# Simple tween for fade out
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
