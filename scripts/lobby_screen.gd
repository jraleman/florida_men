extends Control

@onready var start_button: Button = $VBoxContainer/StartButton

const SLOT_STATUS_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot2/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot3/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot4/SlotStatus",
]

const TOGGLE_BUTTON_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1/ToggleButton",
	"VBoxContainer/PlayerSlots/Slot2/ToggleButton",
	"VBoxContainer/PlayerSlots/Slot3/ToggleButton",
	"VBoxContainer/PlayerSlots/Slot4/ToggleButton",
]

var _status_labels: Array = []
var _toggle_buttons: Array = []

func _ready() -> void:
	GameSession.clear_session()
	for path in SLOT_STATUS_PATHS:
		_status_labels.append(get_node(path) as Label)
	for i in GameSession.MAX_PLAYERS:
		var btn := get_node(TOGGLE_BUTTON_PATHS[i]) as Button
		_toggle_buttons.append(btn)
		btn.pressed.connect(_on_toggle_pressed.bind(i))
	start_button.pressed.connect(_on_start_pressed)
	GameSession.add_player(0)
	for i in range(1, GameSession.MAX_PLAYERS):
		GameSession.add_ai_player(i)
	_refresh_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameSession.go_to("res://scenes/main_menu.tscn")

func _on_toggle_pressed(player_id: int) -> void:
	var currently_ai := GameSession.is_ai_player(player_id)
	GameSession.set_ai_player(player_id, not currently_ai)
	_refresh_slots()

func _refresh_slots() -> void:
	for i in GameSession.MAX_PLAYERS:
		if GameSession.is_ai_player(i):
			(_status_labels[i] as Label).text = "AI"
			(_toggle_buttons[i] as Button).text = "Switch to Human"
		else:
			(_status_labels[i] as Label).text = "Human"
			(_toggle_buttons[i] as Button).text = "Switch to AI"

func _on_start_pressed() -> void:
	GameSession.start_match()
	GameSession.go_to("res://scenes/board.tscn")
