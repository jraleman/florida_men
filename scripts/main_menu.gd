extends Control

@onready var play_button: Button = $Center/Panel/VBoxContainer/PlayButton
@onready var input_settings_button: Button = $Center/Panel/VBoxContainer/InputSettingsButton
@onready var quit_button: Button = $Center/Panel/VBoxContainer/QuitButton

func _ready() -> void:
	GameSession.clear_session()
	play_button.pressed.connect(_on_play_pressed)
	input_settings_button.pressed.connect(_on_input_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	GameSession.go_to("res://scenes/lobby_screen.tscn")

func _on_input_settings_pressed() -> void:
	GameSession.go_to("res://scenes/input_settings.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
