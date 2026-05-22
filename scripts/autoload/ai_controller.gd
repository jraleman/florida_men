extends Node

var _timers: Dictionary = {}
var _pending_releases: Array[String] = []
var _current_scene_name: String = ""

func _ready() -> void:
	_init_timers()

func _init_timers() -> void:
	_release_all()
	_pending_releases.clear()
	_timers.clear()
	for p in GameSession.ai_players:
		_timers[p.id] = {
			"move_t": randf_range(0.0, 0.3),
			"act_t": randf_range(0.3, 1.0),
			"act_hold": false,
			"act_hold_t": 0.0,
			"cur_dir": 0,
		}

func _process(delta: float) -> void:
	for action in _pending_releases:
		Input.action_release(action)
	_pending_releases.clear()

	if GameSession.ai_players.is_empty():
		return

	var scene_name := ""
	var current := get_tree().current_scene
	if current and not current.scene_file_path.is_empty():
		scene_name = current.scene_file_path.get_file().get_basename()

	if scene_name != _current_scene_name:
		_current_scene_name = scene_name
		_init_timers()
		return

	var hold_move: bool = scene_name in ["hurricane_party", "flamingo_fiasco"]
	var hold_action: bool = scene_name == "rocket_man"

	for p in GameSession.ai_players:
		var pid: int = p.id
		if not _timers.has(pid):
			_timers[pid] = {"move_t": 0.0, "act_t": 0.5, "act_hold": false, "act_hold_t": 0.0, "cur_dir": 0}
		_tick_ai(pid, delta, hold_move, hold_action)

func _tick_ai(pid: int, delta: float, hold_move: bool, hold_action: bool) -> void:
	var t: Dictionary = _timers[pid]
	var n: int = pid + 1

	if t.act_hold:
		t.act_hold_t -= delta
		if t.act_hold_t <= 0.0:
			t.act_hold = false
			Input.action_release("player_%d_action" % n)

	t.move_t -= delta
	t.act_t -= delta

	if t.move_t <= 0.0:
		t.move_t = randf_range(0.15, 0.45)
		var old_dir: int = t.cur_dir
		if hold_move and old_dir > 0:
			_release_dir(n, old_dir)
		var dir: int = randi() % 5
		t.cur_dir = dir
		if dir > 0:
			_press_dir(n, dir)
			if not hold_move:
				_pending_releases.append(_dir_action_name(n, dir))

	if t.act_t <= 0.0 and not t.act_hold:
		t.act_t = randf_range(0.4, 1.8)
		Input.action_press("player_%d_action" % n)
		if hold_action:
			t.act_hold = true
			t.act_hold_t = randf_range(0.2, 0.7)
		else:
			_pending_releases.append("player_%d_action" % n)

func _press_dir(n: int, dir: int) -> void:
	match dir:
		1: Input.action_press("player_%d_up" % n)
		2: Input.action_press("player_%d_down" % n)
		3: Input.action_press("player_%d_left" % n)
		4: Input.action_press("player_%d_right" % n)

func _release_dir(n: int, dir: int) -> void:
	match dir:
		1: Input.action_release("player_%d_up" % n)
		2: Input.action_release("player_%d_down" % n)
		3: Input.action_release("player_%d_left" % n)
		4: Input.action_release("player_%d_right" % n)

func _dir_action_name(n: int, dir: int) -> String:
	match dir:
		1: return "player_%d_up" % n
		2: return "player_%d_down" % n
		3: return "player_%d_left" % n
		4: return "player_%d_right" % n
	return ""

func _release_all() -> void:
	for i in GameSession.MAX_PLAYERS:
		var n: int = i + 1
		for suffix in ["up", "down", "left", "right", "action"]:
			Input.action_release("player_%d_%s" % [n, suffix])
