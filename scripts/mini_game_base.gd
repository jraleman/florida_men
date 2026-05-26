class_name MiniGameBase
extends Control

signal game_over(results: Array)

@export var time_limit: float = 30.0

var _timer: float = 0.0
var _running: bool = false
var _player_scores: Dictionary = {}

var _hud: CanvasLayer
var _hud_timer_label: Label
var _hud_score_labels: Dictionary = {}  # player_id -> Label

func _ready() -> void:
	_create_hud()
	game_over.connect(_on_game_over)
	_initialize_player_scores()
	setup()
	start()

# --- Lifecycle hooks (override in subclasses) ---

func setup() -> void:
	pass

func start() -> void:
	_timer = time_limit
	_running = true
	MusicManager.play_music("minigame")
	SoundManager.play("game_start")

func on_tick(_delta: float) -> void:
	pass

func on_timeout() -> void:
	end_game(build_results_from_scores())

# --- Core loop ---

func _process(delta: float) -> void:
	if not _running:
		return
	_timer -= delta
	_update_hud_timer()
	on_tick(delta)
	if _timer <= 0.0:
		_running = false
		on_timeout()

# --- End game ---

func end_game(results: Array) -> void:
	_running = false
	SoundManager.play("game_over")
	game_over.emit(results)

func _on_game_over(results: Array) -> void:
	GameSession.apply_results(results)
	GameSession.go_to("res://scenes/score_board.tscn")

# --- Score helpers ---

func _initialize_player_scores() -> void:
	_player_scores.clear()
	for p in get_players():
		_player_scores[p.id] = 0

func add_score(player_id: int, amount: int = 1) -> void:
	_player_scores[player_id] = _player_scores.get(player_id, 0) + amount
	SoundManager.play("score_point")
	_update_hud_scores()

func get_score(player_id: int) -> int:
	return _player_scores.get(player_id, 0)

func build_results_from_scores() -> Array:
	# Higher score = better placement (for Hurricane Party, Flamingo Fiasco, etc.)
	var pairs := []
	for player_id in _player_scores:
		pairs.append({"player_id": player_id, "score": _player_scores[player_id]})
	pairs.sort_custom(func(a, b): return a.score > b.score)
	var results := []
	for i in pairs.size():
		results.append({"player_id": pairs[i].player_id, "placement": i})
	return results

func build_results_from_order(ordered_player_ids: Array) -> Array:
	# First element = winner (for races, survival games, etc.)
	var results := []
	for i in ordered_player_ids.size():
		results.append({"player_id": ordered_player_ids[i], "placement": i})
	return results

# --- Accessors ---

func get_players() -> Array:
	return GameSession.players

func get_time_remaining() -> float:
	return maxf(_timer, 0.0)

func is_running() -> bool:
	return _running

# --- HUD ---

func _create_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	_hud_timer_label = Label.new()
	_hud_timer_label.set_anchor_and_offset(SIDE_RIGHT, 1.0, -8.0)
	_hud_timer_label.set_anchor_and_offset(SIDE_TOP, 0.0, 8.0)
	_hud_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_hud_timer_label)
	_update_hud_timer()

func _build_hud_score_labels() -> void:
	for lbl in _hud_score_labels.values():
		lbl.queue_free()
	_hud_score_labels.clear()

	var players := get_players()
	for i in players.size():
		var p: Dictionary = players[i]
		var lbl := Label.new()
		lbl.set_anchor_and_offset(SIDE_LEFT, 0.0, 8.0)
		lbl.set_anchor_and_offset(SIDE_TOP, 0.0, 8.0 + i * 24.0)
		_hud.add_child(lbl)
		_hud_score_labels[p.id] = lbl
	_update_hud_scores()

func _update_hud_timer() -> void:
	if _hud_timer_label:
		_hud_timer_label.text = "Time: %d" % ceili(get_time_remaining())

func _update_hud_scores() -> void:
	for player_id in _hud_score_labels:
		var name := ""
		for p in get_players():
			if p.id == player_id:
				name = p.name
				break
		_hud_score_labels[player_id].text = "%s: %d" % [name, _player_scores.get(player_id, 0)]

func show_hud_scores() -> void:
	_build_hud_score_labels()
