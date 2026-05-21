extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var scores_container: VBoxContainer = $VBoxContainer/ScoresContainer
@onready var continue_button: Button = $VBoxContainer/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	_display_scores()

func _display_scores() -> void:
	if GameSession.is_match_over():
		title_label.text = "MATCH OVER!"
		continue_button.text = "Back to Menu"
	else:
		title_label.text = "Round %d Results" % GameSession.round_number
		continue_button.text = "Next Round"

	for child in scores_container.get_children():
		child.queue_free()

	var sorted := GameSession.get_sorted_scores()
	for i in sorted.size():
		var entry: Dictionary = sorted[i]
		var label := Label.new()
		var prefix := ""
		if i == 0 and GameSession.is_match_over():
			prefix = "[WINNER] "
		label.text = "%s%s — %d pts" % [prefix, entry.name, entry.score]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scores_container.add_child(label)

func _on_continue_pressed() -> void:
	if GameSession.is_match_over():
		GameSession.go_to("res://scenes/main_menu.tscn")
	else:
		GameSession.go_to("res://scenes/mini_game_selector.tscn")
