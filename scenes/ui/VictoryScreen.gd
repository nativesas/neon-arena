extends CanvasLayer

signal continue_pressed

func _ready():
	hide()
	$ContinueButton.pressed.connect(_on_continue_pressed)

func show_victory():
	show()

func _on_continue_pressed():
	continue_pressed.emit()
