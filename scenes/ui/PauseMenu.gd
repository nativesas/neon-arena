extends CanvasLayer

signal resume_requested
signal quit_requested

# ... (header/signals same)

var background: ColorRect
var main_container: VBoxContainer
var options_container: VBoxContainer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Important
	layer = 100 # Ensure on top of everything
	
	_setup_background()
	_setup_main_menu()
	_setup_options_menu()

func _setup_background():
	background = ColorRect.new()
	background.size = Vector2(1920, 1080)
	background.color = Color(0, 0, 0, 0.7)
	background.visible = false
	add_child(background)

func _setup_main_menu():
	main_container = VBoxContainer.new()
	main_container.size = Vector2(300, 400)
	main_container.position = Vector2((1920.0 - 300.0) / 2.0, (1080.0 - 400.0) / 2.0)
	main_container.visible = false
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)

	# ... (skip title setup)

func _setup_options_menu():
	options_container = VBoxContainer.new()
	options_container.size = Vector2(400, 500)
	options_container.position = Vector2((1920.0 - 400.0) / 2.0, (1080.0 - 500.0) / 2.0)
	options_container.visible = false
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 15)
	add_child(options_container)
	
	var title = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.2, 1.0, 0.2)
	title.add_theme_font_size_override("font_size", 40)
	options_container.add_child(title)
	
	# Resolution
	_create_label(options_container, "Resolution:")
	var res_opt = OptionButton.new()
	res_opt.add_item("1920 x 1080 (FHD)", 0)
	res_opt.add_item("1280 x 720 (HD)", 1)
	res_opt.add_item("640 x 360 (Retro)", 2)
	res_opt.selected = 0
	res_opt.item_selected.connect(_on_resolution_selected)
	options_container.add_child(res_opt)
	
	# Window Mode
	_create_label(options_container, "Window Mode:")
	var win_opt = OptionButton.new()
	win_opt.add_item("Windowed", 0)
	win_opt.add_item("Fullscreen", 1)
	win_opt.add_item("Windowed Fullscreen", 2)
	win_opt.selected = 0 # Default to Windowed usually safe
	win_opt.item_selected.connect(_on_window_mode_selected)
	options_container.add_child(win_opt)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	options_container.add_child(spacer)
	
	_create_button(options_container, "BACK", _on_options_back_pressed)

func _create_button(parent, text, callback):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 50)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _create_label(parent, text):
	var l = Label.new()
	l.text = text
	parent.add_child(l)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("ESC PRESSED - Toggling Pause")
		# If option menu open, go back. Else toggle pause.
		if options_container.visible:
			_on_options_back_pressed()
		else:
			toggle_pause()

func toggle_pause():
	var tree = get_tree()
	tree.paused = not tree.paused
	print("PAUSE TOGGLED. Tree Paused: ", tree.paused)
	
	background.visible = tree.paused
	if tree.paused:
		main_container.visible = true
		options_container.visible = false
	else:
		main_container.visible = false
		options_container.visible = false

func _on_resume_pressed():
	toggle_pause()

func _on_options_pressed():
	main_container.visible = false
	options_container.visible = true

func _on_options_back_pressed():
	options_container.visible = false
	main_container.visible = true

func _on_exit_pressed():
	get_tree().quit()

# --- Logic ---

func _on_resolution_selected(index):
	var size = Vector2(1920, 1080)
	if index == 1: size = Vector2(1280, 720)
	elif index == 2: size = Vector2(640, 360)
	
	DisplayServer.window_set_size(size)
	# Center window after resize
	var screen_size = DisplayServer.screen_get_size()
	var pos = (screen_size - Vector2i(size)) / 2
	DisplayServer.window_set_position(pos)

func _on_window_mode_selected(index):
	var mode = DisplayServer.WINDOW_MODE_WINDOWED
	if index == 1: mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	elif index == 2: mode = DisplayServer.WINDOW_MODE_FULLSCREEN # Borderless often maps here or separate
	
	DisplayServer.window_set_mode(mode)
