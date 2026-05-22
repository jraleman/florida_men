extends Control

@onready var bindings_grid: GridContainer = $VBoxContainer/BindingsGrid
@onready var save_button: Button = $VBoxContainer/BottomRow/SaveButton
@onready var reset_button: Button = $VBoxContainer/BottomRow/ResetButton
@onready var back_button: Button = $VBoxContainer/BottomRow/BackButton

const SUFFIXES := ["up", "down", "left", "right", "action"]

var _waiting_action: String = ""
var _key_buttons: Dictionary = {}

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_build_grid()

func _build_grid() -> void:
	for child in bindings_grid.get_children():
		child.queue_free()
	_key_buttons.clear()
	_waiting_action = ""
	for i in GameSession.MAX_PLAYERS:
		var n: int = i + 1
		var name_label := Label.new()
		name_label.text = "Player %d" % n
		bindings_grid.add_child(name_label)
		for suffix in SUFFIXES:
			var action_name := "player_%d_%s" % [n, suffix]
			var btn := Button.new()
			btn.text = _get_key_label(action_name)
			btn.custom_minimum_size = Vector2(100, 0)
			btn.pressed.connect(_on_bind_button_pressed.bind(action_name, btn))
			_key_buttons[action_name] = btn
			bindings_grid.add_child(btn)

func _get_key_label(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "[unbound]"
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
	return "[?]"

func _on_bind_button_pressed(action_name: String, btn: Button) -> void:
	if not _waiting_action.is_empty() and _key_buttons.has(_waiting_action):
		(_key_buttons[_waiting_action] as Button).text = _get_key_label(_waiting_action)
	_waiting_action = action_name
	btn.text = "Press a key..."

func _input(event: InputEvent) -> void:
	if _waiting_action.is_empty():
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	if key_event.physical_keycode == KEY_ESCAPE:
		if _key_buttons.has(_waiting_action):
			(_key_buttons[_waiting_action] as Button).text = _get_key_label(_waiting_action)
		_waiting_action = ""
		get_viewport().set_input_as_handled()
		return
	InputMap.action_erase_events(_waiting_action)
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = key_event.physical_keycode
	InputMap.action_add_event(_waiting_action, new_ev)
	if _key_buttons.has(_waiting_action):
		(_key_buttons[_waiting_action] as Button).text = _get_key_label(_waiting_action)
	_waiting_action = ""
	get_viewport().set_input_as_handled()

func _on_save_pressed() -> void:
	GameSession.save_input_settings()

func _on_reset_pressed() -> void:
	GameSession.reset_input_settings()
	_build_grid()

func _on_back_pressed() -> void:
	GameSession.go_to("res://scenes/main_menu.tscn")
