extends Control

@onready var start_button: Button = $VBoxContainer/StartButton

const SLOT_STATUS_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1/Inner/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot2/Inner/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot3/Inner/SlotStatus",
	"VBoxContainer/PlayerSlots/Slot4/Inner/SlotStatus",
]

const TOGGLE_BUTTON_PATHS := [
	"VBoxContainer/PlayerSlots/Slot1/Inner/ToggleButton",
	"VBoxContainer/PlayerSlots/Slot2/Inner/ToggleButton",
	"VBoxContainer/PlayerSlots/Slot3/Inner/ToggleButton",
	"VBoxContainer/PlayerSlots/Slot4/Inner/ToggleButton",
]

const ROUND_OPTIONS := [5, 10, 20, 30]

var _status_labels: Array = []
var _toggle_buttons: Array = []
var _round_buttons: Array = []

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
	_build_rounds_row()

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

func _build_rounds_row() -> void:
	var vbox := $VBoxContainer as VBoxContainer

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.90)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.90, 0.70, 0.10, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var lbl := Label.new()
	lbl.text = "Rounds per match:"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.00, 0.88, 0.55, 1))
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)

	for n in ROUND_OPTIONS:
		var btn := Button.new()
		btn.text = str(n)
		btn.custom_minimum_size = Vector2(70, 38)
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(_on_rounds_pressed.bind(n))
		_round_buttons.append(btn)
		hbox.add_child(btn)

	panel.add_child(hbox)
	vbox.add_child(panel)
	vbox.move_child(panel, start_button.get_index())
	_refresh_round_buttons()

func _on_rounds_pressed(n: int) -> void:
	GameSession.rounds_per_match = n
	_refresh_round_buttons()

func _refresh_round_buttons() -> void:
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.22, 0.16, 0.06, 1)
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.55, 0.42, 0.10, 1)
	style_normal.corner_radius_top_left = 5
	style_normal.corner_radius_top_right = 5
	style_normal.corner_radius_bottom_right = 5
	style_normal.corner_radius_bottom_left = 5
	style_normal.content_margin_left = 8.0
	style_normal.content_margin_top = 6.0
	style_normal.content_margin_right = 8.0
	style_normal.content_margin_bottom = 6.0

	var style_selected := StyleBoxFlat.new()
	style_selected.bg_color = Color(0.62, 0.44, 0.04, 1)
	style_selected.border_width_left = 3
	style_selected.border_width_top = 3
	style_selected.border_width_right = 3
	style_selected.border_width_bottom = 3
	style_selected.border_color = Color(1.00, 0.88, 0.12, 1)
	style_selected.corner_radius_top_left = 5
	style_selected.corner_radius_top_right = 5
	style_selected.corner_radius_bottom_right = 5
	style_selected.corner_radius_bottom_left = 5
	style_selected.content_margin_left = 8.0
	style_selected.content_margin_top = 6.0
	style_selected.content_margin_right = 8.0
	style_selected.content_margin_bottom = 6.0

	for i in _round_buttons.size():
		var btn := _round_buttons[i] as Button
		var is_selected: bool = ROUND_OPTIONS[i] == GameSession.rounds_per_match
		btn.add_theme_stylebox_override("normal", style_selected if is_selected else style_normal)
		btn.add_theme_stylebox_override("hover", style_selected if is_selected else style_normal)
		btn.add_theme_stylebox_override("pressed", style_normal)
		btn.add_theme_color_override("font_color",
			Color(1.00, 0.96, 0.60, 1) if is_selected else Color(0.80, 0.72, 0.50, 1))
