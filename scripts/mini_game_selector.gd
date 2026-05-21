extends Control

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var game_name_label: Label = $VBoxContainer/GameNameLabel
@onready var countdown_label: Label = $VBoxContainer/CountdownLabel

var _countdown: float = 3.0

func _ready() -> void:
	round_label.text = "Round %d / %d" % [GameSession.round_number + 1, GameSession.ROUNDS_PER_MATCH]
	game_name_label.text = GameSession.get_current_mini_game_name()

func _process(delta: float) -> void:
	_countdown -= delta
	countdown_label.text = "Starting in %d..." % ceili(_countdown)
	if _countdown <= 0.0:
		set_process(false)
		GameSession.go_to(GameSession.get_current_mini_game_scene())
