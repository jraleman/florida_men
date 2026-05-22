extends Control

@onready var start_button: Button = $VBoxContainer/StartButton

const SLOT_STATUS_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot2/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot3/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot4/SlotStatus",
]

const ADD_AI_PATHS := [
	"",
	"VBoxContainer/PlayerSlots/Slot2/AddAIButton",
	"VBoxContainer/PlayerSlots/Slot3/AddAIButton",
	"VBoxContainer/PlayerSlots/Slot4/AddAIButton",
]

const PLAYER_CONTROLS := [
	"Move: WASD  |  Action: Space",
	"Move: Arrows  |  Action: Enter",
	"Move: IJKL  |  Action: U",
	"Move: Numpad 8/2/4/6  |  Action: Numpad 0",
]

var _status_labels: Array = []
var _ai_buttons: Array = []

func _ready() -> void:
	for path in SLOT_STATUS_PATHS:
		_status_labels.append(get_node(path) as Label)
	for i in GameSession.MAX_PLAYERS:
		var path: String = ADD_AI_PATHS[i]
		if path.is_empty():
			_ai_buttons.append(null)
		else:
			var btn := get_node(path) as Button
			_ai_buttons.append(btn)
			btn.pressed.connect(_on_add_ai_pressed.bind(i))
	start_button.pressed.connect(_on_start_pressed)
	GameSession.add_player(0)
	_refresh_slots()

func _process(_delta: float) -> void:
	for i in GameSession.MAX_PLAYERS:
		if Input.is_action_just_pressed("player_%d_action" % (i + 1)):
			_toggle_player(i)
	if Input.is_action_just_pressed("ui_cancel"):
		GameSession.go_to("res://scenes/main_menu.tscn")

func _toggle_player(player_id: int) -> void:
	if player_id == 0:
		return
	if GameSession.is_ai_player(player_id):
		GameSession.remove_ai_player(player_id)
	elif _is_joined(player_id):
		GameSession.remove_player(player_id)
	else:
		GameSession.add_player(player_id)
	_refresh_slots()

func _on_add_ai_pressed(player_id: int) -> void:
	if not _is_joined(player_id):
		GameSession.add_ai_player(player_id)
		_refresh_slots()

func _is_joined(player_id: int) -> bool:
	for p in GameSession.players:
		if p.id == player_id:
			return true
	return false

func _refresh_slots() -> void:
	for i in GameSession.MAX_PLAYERS:
		if _is_joined(i):
			if GameSession.is_ai_player(i):
				_status_labels[i].text = "AI (READY)"
			else:
				_status_labels[i].text = "READY"
		else:
			_status_labels[i].text = "Press action to join"
		if i > 0 and _ai_buttons[i] != null:
			(_ai_buttons[i] as Button).disabled = _is_joined(i)
	start_button.disabled = GameSession.players.size() < 1

func _on_start_pressed() -> void:
	GameSession.start_match()
	GameSession.go_to("res://scenes/mini_game_selector.tscn")
