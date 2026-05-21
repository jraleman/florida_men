extends Control

@onready var slot_labels: Array = []
@onready var start_button: Button = $VBoxContainer/StartButton

const SLOT_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1",
	"VBoxContainer/PlayerSlots/Slot2",
	"VBoxContainer/PlayerSlots/Slot3",
	"VBoxContainer/PlayerSlots/Slot4",
]

func _ready() -> void:
	for path in SLOT_PATHS:
		slot_labels.append(get_node(path) as Label)
	start_button.pressed.connect(_on_start_pressed)
	# Player 1 is always in as host
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
		return  # player 1 (host) cannot leave the lobby
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
			slot_labels[i].text = "Player %d  [READY]" % (i + 1)
		else:
			slot_labels[i].text = "Player %d  [ press action to join ]" % (i + 1)
	start_button.disabled = GameSession.players.size() < 1

func _on_start_pressed() -> void:
	GameSession.start_match()
	GameSession.go_to("res://scenes/mini_game_selector.tscn")
