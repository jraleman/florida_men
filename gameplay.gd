extends GameShell

## Party orchestration inside the shared HUD, pause, results and save services.

const Options = preload("res://games/florida_men/florida_men_options.gd")
const Data = preload("res://games/florida_men/data/party_data.gd")
const Match = preload("res://games/florida_men/model/party_match.gd")
const Mini = preload("res://games/florida_men/model/mini_game_state.gd")
const PartyInput = preload("res://games/florida_men/scripts/party_input.gd")
const World = preload("res://games/florida_men/world/party_world.gd")
const Touch = preload("res://games/florida_men/ui/party_touch.gd")
const Sound = preload("res://games/florida_men/audio/party_sound.gd")

var _match := Match.new()
var _mini: RefCounted
var _controls := PartyInput.new()
var _world: Control
var _touch: Control
var _party_panel: PanelContainer
var _phase_title: Label
var _phase_body: Label
var _advance_button: Button
var _humans := 1
var _rounds := 10
var _difficulty := 1
var _phase_clock := 0.0
var _rolling := false
var _roll: Dictionary = {}
var _roll_duration := 1.0
var _last_mini_scores: Array[int] = [0, 0, 0, 0]
var _total_hits: Array[int] = [0, 0, 0, 0]
var _total_misses: Array[int] = [0, 0, 0, 0]
var _frozen_hats: Array[String] = []
var _frozen_characters: Array[int] = []
var _capture_inset := 0.0
var _ui_pixel_scale := 0.0
var _results_scroll: ScrollContainer
var _results_grid: GridContainer
var _stats_grid: GridContainer
var _stats_column: VBoxContainer
var _stats_report: HBoxContainer
var _stats_players: HBoxContainer
var _share_panel: PanelContainer


func game_id() -> String:
	return Options.GAME_ID


func _prepare_session() -> void:
	super()
	_humans = GameSession.player_count()
	music = Sound.music()
	Store.equipped_changed.connect(_on_equipped_changed)
	GameSession.controller_assignments_changed.connect(_clear_input)


func _load_round_settings() -> void:
	super()
	_rounds = Settings.tunable_choice(Options.ROUNDS_KEY)
	_difficulty = Settings.tunable_choice(Options.CPU_KEY)


func _active_player_indices() -> Array[int]:
	return [0, 1, 2, 3]


func _player_name(player: int) -> String:
	return "CPU %d" % (player + 1) if player >= _humans else "Player %d" % (player + 1)


func _hud_player_is_cpu(player_index: int) -> bool:
	return player_index >= _humans


func _build_playfield() -> void:
	_world = World.new()
	_playfield.add_child(_world)
	_world.set("reduced_motion", _reduced_motion_enabled)
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(overlay)
	_party_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("142b32", 0.18)
	panel_style.set_content_margin_all(10)
	panel_style.set_corner_radius_all(8)
	_party_panel.add_theme_stylebox_override("panel", panel_style)
	overlay.add_child(_party_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_party_panel.add_child(layout)
	_phase_title = Label.new()
	_phase_title.add_theme_font_size_override("font_size", 28)
	_phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_phase_title)
	_phase_body = Label.new()
	_phase_body.add_theme_font_size_override("font_size", 22)
	_phase_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_phase_body)
	register_hud_controls(_phase_body, _layout_party, false)
	_advance_button = Button.new()
	_advance_button.custom_minimum_size.y = 52
	_advance_button.pressed.connect(_on_advance_pressed)
	layout.add_child(_advance_button)
	_touch = Touch.new()
	_touch.visible = DisplayServer.is_touchscreen_available()
	_touch.connect("contact_changed", _on_touch_contact)
	overlay.add_child(_touch)
	register_hud_controls(_touch, _layout_party)
	_hint.hide()
	_build_results_layout()
	get_viewport().size_changed.connect(_layout_party)
	_party_panel.minimum_size_changed.connect(func() -> void: _layout_party.call_deferred())
	AudioManager.attach_ui_sounds(_party_panel)
	_layout_party()


func _build_results_layout() -> void:
	_results_scroll = ScrollContainer.new()
	_results_scroll.follow_focus = true
	_results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_results_scroll.minimum_size_changed.connect(
		func() -> void: _layout_results.call_deferred(_ui_pixel_scale))
	_round_over.add_child(_results_scroll)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_scroll.add_child(column)
	var center := _round_panel.get_parent() as Control
	for panel: PanelContainer in [_round_panel, _score_panel]:
		panel.reparent(column)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.hide()
	_results_grid = GridContainer.new()
	_results_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_player_one_score.get_parent().get_parent().get_parent().add_child(_results_grid)
	_stats_players = player_stats_panel(0).get_parent() as HBoxContainer
	_stats_report = _stats_players.get_parent() as HBoxContainer
	_share_panel = _stats_report.get_node("SharePanel") as PanelContainer
	_stats_column = VBoxContainer.new()
	_stats_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_report.add_child(_stats_column)
	_stats_column.hide()
	_stats_grid = GridContainer.new()
	_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_players.add_child(_stats_grid)
	for player in _player_ui:
		(player["result_card"] as Control).reparent(_results_grid)
		(player["stats_card"] as Control).reparent(_stats_grid)


func _reset_round_state() -> void:
	_humans = GameSession.player_count()
	_match.configure(_humans, _rounds, _rng.randi())
	_mini = null
	_phase_clock = 0.0
	_rolling = false
	_roll.clear()
	_total_hits.fill(0)
	_total_misses.fill(0)
	_frozen_hats.clear()
	_frozen_characters.clear()
	_clear_input()
	_sync_hud_controls()
	_sync_scores()
	_set_roster()
	_world.call("show_board")
	_refresh_phase()


func _activate_round() -> void:
	_announce_cue("start", "Four guests start with ten board coins each.")


func _configure_mode_ui() -> void:
	super()
	_time_caption.text = "MINIGAMES"
	_time_label.text = "%d/%d" % [_match.round_number, _rounds]
	_time_progress.hide()
	_update_streaks()
	for player in 4:
		(_player_ui[player]["card"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var layout := player_stats_panel(player).get_node("Layout")
		(layout.get_node("ScoreCaption") as Label).text = "BOARD COINS"
		(layout.get_node("Stats/HitsCaption") as Label).text = "Minigame wins"
		(layout.get_node("Stats/MissesCaption") as Label).text = "Other placements"
		(layout.get_node("Stats/AccuracyCaption") as Label).text = "Win rate"
		(layout.get_node("Stats/StreakCaption") as Label).text = "Placement points"
	(_game_hits_stat.get_parent().get_node("Caption") as Label).text = "MINIGAME WINS"
	(_game_accuracy_stat.get_parent().get_node("Caption") as Label).text = "GUEST WIN RATE"
	_round_instructions.text = "Minigame placements paid 5 / 3 / 1 / 0 board coins. Sunshine Tokens buy cosmetic hats."
	_share_card_hint.text = "Your local party image. Its QR opens the studio homepage, not public run statistics."


func _update_streaks() -> void:
	for player in _player_ui.size():
		_streak_label(player).text = "%d WINS" % _match.wins[player]


func _update_round(delta: float, _time_left: float) -> void:
	_phase_clock += delta
	match _match.phase:
		Match.Phase.BOARD:
			if _rolling:
				_world.call("sync_board", _match, _roll, _phase_clock / _roll_duration)
				if _phase_clock >= _roll_duration:
					_rolling = false
					_match.finish_board_turn()
					_phase_clock = 0.0
					var change := int(_roll["change"])
					_announce_cue("coin" if change >= 0 else "bump",
						"%s lands on %s: %+d coins." % [
							_player_name(int(_roll["player"])),
							Data.SPACE_NAMES[int(_roll["type"])], change,
						])
					_sync_scores()
					_refresh_phase()
			elif _match.is_cpu(_match.turn) and _phase_clock >= 0.65:
				_roll_die()
		Match.Phase.MINIGAME:
			_mini.call("step", delta, _controls.snapshot())
			_world.call("sync_minigame", _mini)
			_time_label.text = str(ceili(maxf(0.0, Mini.LIMIT - float(_mini.get("elapsed")))))
			var changed := false
			for player in 4:
				var value: int = _mini.get("scores")[player]
				if value != _last_mini_scores[player]:
					AudioManager.request_caption("%s: %+d in %s." % [
						_player_name(player), value - _last_mini_scores[player],
						Data.mini_game(_match.current_game())["title"],
					])
					changed = true
					_last_mini_scores[player] = value
			if changed:
				AudioManager.play_sfx(Sound.cue("tag"), -7.0)
			if bool(_mini.get("finished")):
				_complete_minigame()


func _handle_gameplay_input(event: InputEvent) -> void:
	var pad := GameSession.controller_player_index(event.device) \
		if event is InputEventJoypadButton or event is InputEventJoypadMotion else -1
	var player := _controls.handle_event(event, _humans, pad)
	if player >= 0 and _match.phase != Match.Phase.MINIGAME:
		_request_action(player)


func _input(event: InputEvent) -> void:
	if not _round_active or get_tree().paused:
		return
	var owned := false
	if event is InputEventKey:
		for binding in Options.CONTROL_BINDINGS:
			if event.is_action(binding["action"]):
				owned = true
				break
	elif event is InputEventJoypadMotion:
		owned = event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	elif event is InputEventJoypadButton:
		owned = event.button_index in [
			JOY_BUTTON_A, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
		]
	if owned:
		_handle_gameplay_input(event)
		get_viewport().set_input_as_handled()


func _request_action(player: int) -> void:
	if not _round_active or player < 0 or player >= _humans:
		return
	match _match.phase:
		Match.Phase.BOARD:
			if not _rolling and player == _match.turn:
				_roll_die()
		Match.Phase.BRIEFING:
			_start_minigame()
		Match.Phase.STANDINGS:
			_match.advance()
			_phase_clock = 0.0
			_clear_input()
			if _match.phase == Match.Phase.FINISHED:
				_end_round()
			else:
				_world.call("show_board")
				_refresh_phase()


func _roll_die() -> void:
	_roll = _match.roll()
	_roll_duration = 0.5 + float(_roll["die"]) * 0.12
	_phase_clock = 0.0
	_rolling = true
	_announce_cue("roll", "%s rolls %d." % [_player_name(int(_roll["player"])), int(_roll["die"])])
	_refresh_phase()


func _start_minigame() -> void:
	_match.start_minigame()
	_clear_input()
	_mini = Mini.new()
	var cpu_seats: Array[bool] = []
	for player in 4:
		cpu_seats.append(_match.is_cpu(player))
	_mini.call("configure", _match.current_game(), _rng.randi(), cpu_seats, _difficulty)
	_last_mini_scores.fill(0)
	_world.call("show_minigame", _match.current_game())
	_world.call("sync_minigame", _mini)
	_announce_cue("start", str(Data.mini_game(_match.current_game())["title"]) + " begins.")
	_refresh_phase()


func _complete_minigame() -> void:
	for player in 4:
		_total_hits[player] += int(_mini.get("hits")[player])
		_total_misses[player] += int(_mini.get("misses")[player])
	var metrics: Array[float] = _mini.call("metrics")
	_match.finish_minigame(metrics)
	_clear_input()
	_sync_scores()
	_announce_cue("finish", "Minigame complete. Placement coins are banked on the board.")
	_refresh_phase()


func _refresh_phase() -> void:
	_party_panel.show()
	_advance_button.show()
	_advance_button.disabled = false
	_callout.text = "PARTY %d / %d" % [mini(_match.round_number + 1, _rounds), _rounds]
	_time_caption.text = "MINIGAMES"
	_time_label.text = "%d/%d" % [_match.round_number, _rounds]
	match _match.phase:
		Match.Phase.BOARD:
			_phase_title.text = "%s's board turn" % _player_name(_match.turn)
			_phase_body.text = "Every guest rolls once, then the next headline plays."
			if not _roll.is_empty() and not _rolling:
				_phase_body.text = "%s: %s, %+d coins." % [
					_player_name(int(_roll["player"])), Data.SPACE_NAMES[int(_roll["type"])],
					int(_roll["change"]),
				]
			_advance_button.text = "Rolling %d..." % int(_roll["die"]) if _rolling \
				else "CPU is choosing..." if _match.is_cpu(_match.turn) else "Roll die"
			if not _rolling and not _match.is_cpu(_match.turn):
				_advance_button.text = "P%d / Roll" % (_match.turn + 1)
			_advance_button.disabled = _rolling or _match.is_cpu(_match.turn)
			if not _rolling:
				_world.call("sync_board", _match, {}, 1.0)
		Match.Phase.BRIEFING:
			var data := Data.mini_game(_match.current_game())
			_phase_title.text = str(data["title"])
			_phase_body.text = "%s\n%s" % [data["rules"], data["controls"]]
			_advance_button.text = "Start minigame"
		Match.Phase.MINIGAME:
			var data := Data.mini_game(_match.current_game())
			_phase_title.text = str(data["title"])
			_phase_body.text = str(data["controls"])
			_advance_button.hide()
			_time_caption.text = "SECONDS"
		Match.Phase.STANDINGS:
			_phase_title.text = "Minigame %d complete - board standings" % _match.round_number
			_phase_body.text = _standings_text()
			_advance_button.text = "Finish party" if _match.round_number >= _rounds else "Next board round"
	_layout_party.call_deferred()


func _standings_text() -> String:
	var lines := PackedStringArray()
	for entry in _match.standings():
		lines.append("%s: %d coins / %d wins / %d placement points" % [
			entry["name"], entry["coins"], entry["wins"], entry["points"],
		])
	return "\n".join(lines)


func _sync_scores() -> void:
	for player in 4:
		_scores[player] = _match.coins[player]
		_best_streaks[player] = _match.wins[player]
	_update_scores()
	_update_streaks()


func _finish_round() -> void:
	_clear_input()
	_party_panel.hide()
	_touch.hide()
	_frozen_hats = _equipped_hats()
	_frozen_characters = _selected_characters()


func _describe_round_outcome(_one: int, _two: int) -> Dictionary:
	if _match.phase != Match.Phase.FINISHED:
		return {"result": "PARTY STOPPED", "subtitle": "An incomplete party earns no shop tokens.",
			"color": Data.COLORS[0]}
	var winners := _match.winners()
	var names := PackedStringArray()
	for player in winners:
		names.append(_player_name(player))
	return {
		"result": "%s WINS!" % names[0].to_upper() if winners.size() == 1 else "SHARED HOLIDAY!",
		"subtitle": "Coins decide; wins break ties.\n" + _standings_text(),
		"color": Data.COLORS[winners[0]],
	}


func _round_length_seconds() -> float:
	return _round_elapsed


func _round_mode_summary() -> String:
	return "%d humans + %d CPUs / %d minigames" % [_humans, 4 - _humans, _rounds]


func _best_combo_summary() -> String:
	return "%d of %d minigames completed. Coins first; wins break ties." % [_match.round_number, _rounds]


func _round_points_earned(_one: int, _two: int) -> int:
	return _match.payout()


func _award_round_achievements(_one: int, _two: int) -> void:
	if _match.phase != Match.Phase.FINISHED:
		return
	_unlock_round_achievement("fm_first_party")
	for player in _humans:
		if _match.wins[player] >= 3:
			_unlock_round_achievement("fm_three_wins")
		if _match.coins[player] >= 40:
			_unlock_round_achievement("fm_forty_coins")
		if _match.winners().has(player):
			_unlock_round_achievement("fm_champion")


func _round_totals() -> Dictionary:
	var wins := 0
	for value in _match.wins:
		wins += value
	return {"hits": wins, "attempts": _match.round_number * 4}


func _player_stats(player: int) -> Dictionary:
	var wins := _match.wins[player]
	return {
		"score": _scores[player], "hits": wins, "misses": maxi(0, _match.round_number - wins),
		"accuracy": _accuracy_percent(wins, _match.round_number), "streak": _match.points[player],
		"details": [
			{"label": "Scoring actions", "value": str(_total_hits[player])},
			{"label": "Misses / bumps", "value": str(_total_misses[player])},
		],
	}


func _populate_player_stats(player: int) -> void:
	super(player)
	(_player_ui[player]["stats"]["streak"] as Label).text = str(_match.points[player])
	_layout_results(_ui_pixel_scale)


func _share_payload() -> Dictionary:
	var payload := super()
	payload["score_caption"] = "BOARD COINS / P1 / P2 / P3 / P4"
	payload["accuracy_caption"] = "GUEST WIN RATE"
	payload["hits_caption"] = "MINIGAME WINS"
	payload["combo_caption"] = "TOP WINS"
	payload["challenge"] = "MOST COINS WINS THE HOLIDAY"
	payload["qr_heading"] = "PLAY FLORIDA MEN"
	payload["qr_copy"] = "Visit the studio homepage. This local party image is not a public run record."
	payload["fm_hats"] = _frozen_hats.duplicate()
	payload["fm_characters"] = _frozen_characters.duplicate()
	payload["fm_standings"] = _match.standings().duplicate(true)
	return payload


func open_pause_menu() -> void:
	_clear_input()
	super()


func _set_reduced_motion_enabled(value: bool) -> void:
	super(value)
	if _world != null:
		_world.set("reduced_motion", value)


func _on_controls_changed() -> void:
	_clear_input()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_input()


func _on_advance_pressed() -> void:
	_request_action(_match.turn if _match.phase == Match.Phase.BOARD else 0)


func _on_touch_contact(finger: int, verb: String) -> void:
	if _controls.set_touch(finger, verb) and _match.phase != Match.Phase.MINIGAME:
		_request_action(0)


func _clear_input() -> void:
	_controls.clear()
	if _touch != null:
		_touch.call("clear")


func _set_roster() -> void:
	var names: Array[String] = []
	for player in 4:
		names.append(_player_name(player))
	_world.call("set_roster", names, _equipped_hats(), _selected_characters())


func _equipped_hats() -> Array[String]:
	var result: Array[String] = []
	for player in 4:
		result.append(Store.equipped_id(game_id(), "fm_hat_p%d" % (player + 1)))
	return result


func _selected_characters() -> Array[int]:
	var result: Array[int] = []
	for player in 4:
		var character := mini(player, Data.CHARACTERS.size() - 1)
		if player < _humans:
			var entry := GameSession.character_for_player(player)
			for index in Data.CHARACTERS.size():
				if entry["id"] == Data.CHARACTERS[index]["id"]:
					character = index
		result.append(character)
	return result


func _on_equipped_changed(game: String, _slot: String, _item: String) -> void:
	if game != game_id() or _world == null or not _round_active:
		return
	_set_roster()
	if _match.phase == Match.Phase.MINIGAME:
		_world.call("show_minigame", _match.current_game())
		_world.call("sync_minigame", _mini)
	else:
		_world.call("show_board")
		_world.call("sync_board", _match, _roll if _rolling else {}, 1.0)


func _announce_cue(cue: String, caption: String) -> void:
	AudioManager.play_sfx(Sound.cue(cue), -5.0)
	AudioManager.request_caption(caption)


func _layout_party() -> void:
	if _party_panel == null:
		return
	var screen := get_viewport_rect().size
	var pixel_scale := _shell_hud_unit
	if not is_equal_approx(pixel_scale, _ui_pixel_scale):
		_ui_pixel_scale = pixel_scale
		_phase_title.add_theme_font_size_override("font_size", roundi(16 * pixel_scale))
		_phase_body.add_theme_font_size_override("font_size", roundi(14 * pixel_scale))
		_advance_button.add_theme_font_size_override("font_size", roundi(16 * pixel_scale))
		_advance_button.custom_minimum_size = Vector2(144, 44) * pixel_scale
		_advance_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_phase_body.visible = hud_controls_expanded() or _match.phase == Match.Phase.BRIEFING
	_phase_title.visible = hud_controls_expanded() or _match.phase in [
		Match.Phase.BRIEFING, Match.Phase.STANDINGS,
	]
	_advance_button.tooltip_text = "%s\n%s" % [_phase_title.text, _phase_body.text]
	_advance_button.accessibility_description = _advance_button.tooltip_text
	_phase_title.tooltip_text = _phase_body.text
	_phase_title.accessibility_description = _phase_body.text
	var width := minf(560 * pixel_scale, screen.x - 20 * pixel_scale)
	_party_panel.size.x = width
	var height := _party_panel.get_combined_minimum_size().y
	var touch_height := 135.0 * pixel_scale if _touch.visible else 0.0
	var bottom := maxf(10.0 * pixel_scale + touch_height, _capture_inset)
	_party_panel.position = Vector2((screen.x - width) * 0.5, screen.y - bottom - height)
	_party_panel.size = Vector2(width, height)
	_touch.position = Vector2(38, screen.y - touch_height - 12.0 * pixel_scale)
	_touch.size = Vector2(screen.x - 76.0, touch_height)
	var top := _shell_top_bar.get_global_rect().end.y + 8.0 * pixel_scale
	_world.position = Vector2(0, top)
	_world.size = Vector2(screen.x, maxf(1.0, _party_panel.position.y - top - 8 * pixel_scale))
	_layout_results(pixel_scale)


func _layout_results(pixel_scale: float) -> void:
	if _results_scroll == null:
		return
	_results_scroll.follow_focus = is_zero_approx(_capture_inset)
	var screen := get_viewport_rect().size
	_results_scroll.position = Vector2(38, 30)
	_results_scroll.size = screen - Vector2(76, 60 + _capture_inset)
	var compact := get_window().size.x < 700 or screen.x < 1600
	_results_grid.columns = 2 if get_window().size.x < 600 else 4
	_stats_grid.columns = 2 if compact else 4
	var report_parent: Node = _stats_column if compact else _stats_report
	if _stats_players.get_parent() != report_parent:
		_stats_players.reparent(report_parent)
		_share_panel.reparent(report_parent)
	_stats_column.visible = compact
	_share_card_preview.custom_minimum_size.y = maxf(189, 180 * pixel_scale) if compact else 189
	_round_panel.custom_minimum_size.x = minf(800, _results_scroll.size.x)
	_score_panel.custom_minimum_size.x = minf(1180, _results_scroll.size.x)
	for panel: PanelContainer in [_round_panel, _score_panel]:
		for node in panel.find_children("*", "", true, false):
			if not node is Label and not node is Button:
				continue
			var control := node as Control
			if not control.has_meta("fm_base_font"):
				control.set_meta("fm_base_font", control.get_theme_font_size("font_size"))
			var minimum := 12.0 if node is Label else 17.0
			var font_size := maxi(int(control.get_meta("fm_base_font")), roundi(minimum * pixel_scale))
			if control.get_theme_font_size("font_size") != font_size:
				control.add_theme_font_size_override("font_size", font_size)
			if node is Button:
				control.custom_minimum_size.y = maxf(52, 44 * pixel_scale)


func _set_capture_inset(bottom: float) -> void:
	_capture_inset = bottom
	_layout_party()
