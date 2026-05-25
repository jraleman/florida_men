extends Control

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var standings_label: Label = $VBoxContainer/StandingsLabel
@onready var game_name_label: Label = $VBoxContainer/GamePanel/GameVBox/GameNameLabel
@onready var rules_label: Label = $VBoxContainer/GamePanel/GameVBox/RulesLabel
@onready var countdown_label: Label = $VBoxContainer/CountdownLabel

var _countdown: float = 3.0

func _ready() -> void:
	round_label.text = "Round %d / %d" % [GameSession.round_number + 1, GameSession.rounds_per_match]
	game_name_label.text = GameSession.get_current_mini_game_name()
	rules_label.text = "\n".join(GameSession.get_current_mini_game_rules())
	# Only show standings from round 2 onward — nothing to show before the first round
	if GameSession.round_number > 0:
		standings_label.text = "Standings:  %s" % GameSession.get_standings_text()
	else:
		standings_label.text = ""

func _process(delta: float) -> void:
	_countdown -= delta
	countdown_label.text = "Starting in %d..." % ceili(_countdown)
	if _countdown <= 0.0:
		set_process(false)
		GameSession.go_to(GameSession.get_current_mini_game_scene())
