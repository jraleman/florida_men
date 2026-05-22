extends MiniGameBase

const GRID_SIZE := 8
const CELL_SIZE := 64.0
const WRANGLES_TO_WIN := 3
const BASE_GATOR_INTERVAL := 1.5
const MIN_GATOR_INTERVAL := 0.3

const PLAYER_COLORS := [Color.CYAN, Color.YELLOW, Color.MAGENTA, Color.LIME_GREEN]
const START_POSITIONS := [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 7), Vector2i(7, 7)]

var gator_pos := Vector2i(4, 4)
var player_positions: Dictionary = {}
var wrangle_counts: Dictionary = {}
var _gator_timer: float = 0.0
var _gator_interval: float = BASE_GATOR_INTERVAL
var _finish_order: Array = []
var _grid_origin: Vector2

func setup() -> void:
	time_limit = 60.0
	show_hud_scores()
	var players := get_players()
	for i in players.size():
		var pid: int = players[i].id
		player_positions[pid] = START_POSITIONS[i % START_POSITIONS.size()]
		wrangle_counts[pid] = 0
	gator_pos = Vector2i(GRID_SIZE / 2, GRID_SIZE / 2)
	_gator_timer = _gator_interval

func on_tick(delta: float) -> void:
	_handle_input()
	_gator_timer -= delta
	if _gator_timer <= 0.0:
		_move_gator()
		_gator_timer = _gator_interval
	_check_wrangles()
	queue_redraw()

func _handle_input() -> void:
	for p in get_players():
		var pid: int = p.id
		if pid in _finish_order:
			continue
		var n := pid + 1
		var pos: Vector2i = player_positions[pid]
		if Input.is_action_just_pressed("player_%d_up" % n):
			pos.y -= 1
		elif Input.is_action_just_pressed("player_%d_down" % n):
			pos.y += 1
		elif Input.is_action_just_pressed("player_%d_left" % n):
			pos.x -= 1
		elif Input.is_action_just_pressed("player_%d_right" % n):
			pos.x += 1
		player_positions[pid] = pos.clamp(Vector2i.ZERO, Vector2i(GRID_SIZE - 1, GRID_SIZE - 1))

func _move_gator() -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for d in dirs:
		var next: Vector2i = gator_pos + d
		if next.x >= 0 and next.x < GRID_SIZE and next.y >= 0 and next.y < GRID_SIZE:
			gator_pos = next
			return

func _check_wrangles() -> void:
	for p in get_players():
		var pid: int = p.id
		if pid in _finish_order:
			continue
		if player_positions.get(pid) == gator_pos:
			wrangle_counts[pid] += 1
			add_score(pid, 1)
			_gator_interval = maxf(_gator_interval - 0.15, MIN_GATOR_INTERVAL)
			_move_gator()
			if wrangle_counts[pid] >= WRANGLES_TO_WIN:
				_finish_order.append(pid)
				if _finish_order.size() >= get_players().size():
					end_game(build_results_from_order(_finish_order))
					return

func on_timeout() -> void:
	var remaining := []
	for p in get_players():
		if p.id not in _finish_order:
			remaining.append(p.id)
	remaining.sort_custom(func(a, b): return wrangle_counts.get(a, 0) > wrangle_counts.get(b, 0))
	end_game(build_results_from_order(_finish_order + remaining))

func _draw() -> void:
	var vp := get_viewport_rect().size
	var grid_px := CELL_SIZE * GRID_SIZE
	_grid_origin = (vp - Vector2(grid_px, grid_px)) / 2.0
	var font := ThemeDB.fallback_font

	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var cell_color := Color(0.15, 0.15, 0.15) if (x + y) % 2 == 0 else Color(0.22, 0.22, 0.22)
			draw_rect(Rect2(_grid_origin + Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE), cell_color)

	# Gator
	var gator_rect := Rect2(
		_grid_origin + Vector2(gator_pos) * CELL_SIZE + Vector2(6, 6),
		Vector2.ONE * (CELL_SIZE - 12)
	)
	draw_rect(gator_rect, Color(0.1, 0.6, 0.1))
	draw_string(font, _grid_origin + Vector2(gator_pos) * CELL_SIZE + Vector2(10, CELL_SIZE - 10),
		"GTR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Player cursors
	var players := get_players()
	for i in players.size():
		var pid: int = players[i].id
		if pid not in player_positions:
			continue
		var pos: Vector2i = player_positions[pid]
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		var pr := Rect2(_grid_origin + Vector2(pos) * CELL_SIZE + Vector2(12, 12), Vector2.ONE * (CELL_SIZE - 24))
		draw_rect(pr, col)
		draw_string(font, _grid_origin + Vector2(pos) * CELL_SIZE + Vector2(10, CELL_SIZE - 8),
			"x%d" % wrangle_counts.get(pid, 0), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

	draw_string(font, Vector2(8, vp.y - 10),
		"First to %d wrangles wins!" % WRANGLES_TO_WIN, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
