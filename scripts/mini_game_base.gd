class_name MiniGameBase
extends Control

signal game_over(results: Array)

@export var time_limit: float = 60.0

var _timer: float = 0.0
var _running: bool = false

func _ready() -> void:
	setup()
	start()

func setup() -> void:
	pass

func start() -> void:
	_timer = time_limit
	_running = true

func _process(delta: float) -> void:
	if not _running:
		return
	_timer -= delta
	on_tick(delta)
	if _timer <= 0.0:
		_running = false
		on_timeout()

func on_tick(_delta: float) -> void:
	pass

func on_timeout() -> void:
	end_game([])

func end_game(results: Array) -> void:
	_running = false
	game_over.emit(results)

func get_time_remaining() -> float:
	return maxf(_timer, 0.0)

func get_players() -> Array:
	return GameSession.players
