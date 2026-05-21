extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var round_winner_label: Label = $VBoxContainer/RoundWinnerLabel
@onready var scores_container: VBoxContainer = $VBoxContainer/ScoresContainer
@onready var continue_button: Button = $VBoxContainer/ContinueButton

const PLACEMENT_LABELS := ["1st", "2nd", "3rd", "4th"]

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	_display_scores()

func _display_scores() -> void:
	if GameSession.is_match_over():
		title_label.text = "MATCH OVER!"
		round_winner_label.text = "Winner: %s" % GameSession.get_last_round_winner_name()
		continue_button.text = "Back to Menu"
	else:
		title_label.text = "Round %d Results" % GameSession.round_number
		var winner := GameSession.get_last_round_winner_name()
		round_winner_label.text = "%s wins this round!" % winner if winner else ""
		continue_button.text = "Next Round"

	for child in scores_container.get_children():
		child.queue_free()

	var sorted := GameSession.get_sorted_scores()
	for i in sorted.size():
		var entry: Dictionary = sorted[i]
		var pts_earned: int = GameSession.last_round_points.get(entry.id, 0)
		var placement: String = PLACEMENT_LABELS[mini(i, PLACEMENT_LABELS.size() - 1)]
		var match_winner_tag := "  [MATCH WINNER]" if (i == 0 and GameSession.is_match_over()) else ""
		var label := Label.new()
		label.text = "%s  %s  +%d pts  (total: %d)%s" % [
			placement, entry.name, pts_earned, entry.score, match_winner_tag
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scores_container.add_child(label)

func _on_continue_pressed() -> void:
	if GameSession.is_match_over():
		GameSession.go_to("res://scenes/main_menu.tscn")
	else:
		GameSession.go_to("res://scenes/mini_game_selector.tscn")
