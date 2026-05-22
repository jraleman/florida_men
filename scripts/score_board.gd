extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var round_winner_label: Label = $VBoxContainer/RoundWinnerLabel
@onready var scores_container: VBoxContainer = $VBoxContainer/ScoresContainer
@onready var history_container: VBoxContainer = $VBoxContainer/HistoryContainer
@onready var rematch_button: Button = $VBoxContainer/RematchButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton

const PLACEMENT_LABELS := ["1st", "2nd", "3rd", "4th"]

func _ready() -> void:
	rematch_button.pressed.connect(_on_rematch_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	_display_scores()

func _display_scores() -> void:
	var match_over := GameSession.is_match_over()

	if match_over:
		title_label.text = "MATCH OVER!"
		round_winner_label.text = "Last round won by %s" % GameSession.get_last_round_winner_name()
		continue_button.text = "Back to Menu"
		rematch_button.visible = true
	else:
		title_label.text = "Round %d Results" % GameSession.round_number
		var winner := GameSession.get_last_round_winner_name()
		round_winner_label.text = "%s wins this round!" % winner if winner else ""
		continue_button.text = "Next Round"
		rematch_button.visible = false

	_populate_scores(match_over)
	_populate_history(match_over)

func _populate_scores(match_over: bool) -> void:
	for child in scores_container.get_children():
		child.queue_free()

	var sorted := GameSession.get_sorted_scores()
	var prev_score := -1
	var display_rank := 0
	for i in sorted.size():
		var entry: Dictionary = sorted[i]
		if entry.score != prev_score:
			display_rank = i
		prev_score = entry.score

		var pts_earned: int = GameSession.last_round_points.get(entry.id, 0)
		var placement: String = PLACEMENT_LABELS[mini(display_rank, PLACEMENT_LABELS.size() - 1)]

		var tied: bool = i > 0 and sorted[i - 1].score == entry.score
		var tie_tag := " (tied)" if tied else ""

		var winner_tag := "  *** MATCH WINNER ***" if (display_rank == 0 and match_over) else ""

		var label := Label.new()
		if match_over:
			label.text = "%s  %s%s  %d pts total  (%d round wins)%s" % [
				placement, entry.name, tie_tag, entry.score, entry.wins, winner_tag
			]
		else:
			label.text = "%s  %s  +%d pts  (total: %d)" % [
				placement, entry.name, pts_earned, entry.score
			]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scores_container.add_child(label)

func _populate_history(match_over: bool) -> void:
	for child in history_container.get_children():
		child.queue_free()
	history_container.visible = match_over
	if not match_over:
		return

	var sep := Label.new()
	sep.text = "--- Round History ---"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_container.add_child(sep)

	for round_data in GameSession.round_history:
		var parts := []
		var players := GameSession.players
		# Sort player display by placement this round
		var sorted_players := players.duplicate()
		sorted_players.sort_custom(func(a, b):
			return round_data.placements.get(a.id, 99) < round_data.placements.get(b.id, 99)
		)
		for p in sorted_players:
			var pl: int = round_data.placements.get(p.id, 99)
			var lbl: String = PLACEMENT_LABELS[mini(pl, PLACEMENT_LABELS.size() - 1)]
			parts.append("%s %s" % [lbl, p.name])
		var row := Label.new()
		row.text = "%s:  %s" % [round_data.game_name, "  |  ".join(PackedStringArray(parts))]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		history_container.add_child(row)

func _on_rematch_pressed() -> void:
	GameSession.rematch()

func _on_continue_pressed() -> void:
	if GameSession.is_match_over():
		GameSession.go_to("res://scenes/main_menu.tscn")
	else:
		GameSession.go_to("res://scenes/mini_game_selector.tscn")
