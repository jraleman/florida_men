extends Control

@onready var start_button: Button = $VBoxContainer/StartButton

const SLOT_STATUS_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot2/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot3/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot4/SlotStatus",
]

const PLAYER_CONTROLS := [
	"Move: WASD  |  Action: Space",
	"Move: Arrows  |  Action: Enter",
	"Move: IJKL  |  Action: U",
	"Move: Numpad 8/2/4/6  |  Action: Numpad 0",
]

var _status_labels: Array = []

func _ready() -> void:
	for path in SLOT_STATUS_PATHS:
		_status_labels.append(get_node(path) as Label)
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
		return  # player 1 (host) cannot leave
	var already_joined := false
	for p in GameSession.players:
		if p.id == player_id:
			already_joined = true
			break
	if already_joined:
		GameSession.remove_player(player_id)
	else:
		GameSession.add_player(player_id)
	_refresh_slots()

func _refresh_slots() -> void:
	var joined_ids := []
	for p in GameSession.players:
		joined_ids.append(p.id)
	for i in GameSession.MAX_PLAYERS:
		if i in joined_ids:
			_status_labels[i].text = "READY"
		else:
			_status_labels[i].text = "Press action to join"
	start_button.disabled = GameSession.players.size() < 1

func _on_start_pressed() -> void:
	GameSession.start_match()
	GameSession.go_to("res://scenes/mini_game_selector.tscn")
