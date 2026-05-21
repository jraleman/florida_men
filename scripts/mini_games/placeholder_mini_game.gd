extends MiniGameBase

@export var game_title: String = "Mini Game"
@export var game_headline: String = ""

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var headline_label: Label = $VBoxContainer/HeadlineLabel
@onready var finish_button: Button = $VBoxContainer/FinishButton

func _ready() -> void:
	super()

func setup() -> void:
	title_label.text = game_title
	headline_label.text = game_headline
	finish_button.pressed.connect(_on_finish_pressed)

func start() -> void:
	pass  # no auto-timer in placeholder; button drives the end

func _on_finish_pressed() -> void:
	var players := get_players()
	var player_ids := []
	for p in players:
		player_ids.append(p.id)
	player_ids.shuffle()
	var results := []
	for i in player_ids.size():
		results.append({"player_id": player_ids[i], "placement": i})
	GameSession.apply_results(results)
	GameSession.go_to("res://scenes/score_board.tscn")
