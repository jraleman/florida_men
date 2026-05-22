extends MiniGameBase

const GRID_SIZE := 12
const CELL_SIZE := 50.0
const INITIAL_PYTHONS := 4
const MAX_PYTHONS := 18
const PYTHON_MOVE_INTERVAL := 0.55
const SPAWN_INTERVAL := 7.0

const PLAYER_COLORS := [Color.CYAN, Color.YELLOW, Color.MAGENTA, Color.LIME_GREEN]
const TRAP_BG_COLORS := [Color(0.0, 0.4, 0.6), Color(0.6, 0.6, 0.0), Color(0.6, 0.0, 0.6), Color(0.0, 0.6, 0.2)]
const PYTHON_COLOR := Color(0.15, 0.7, 0.15)
const GRID_EVEN := Color(0.10, 0.10, 0.10)
const GRID_ODD := Color(0.15, 0.15, 0.15)

var player_cursor: Dictionary = {}   # player_id -> Vector2i
var _traps: Dictionary = {}          # Vector2i -> player_id
var _pythons: Array = []             # {pos: Vector2i, dir: Vector2i, alive: bool}
var _python_timer: float = 0.0
var _spawn_timer: float = 0.0
var _grid_origin: Vector2

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func setup() -> void:
	time_limit = 60.0
	show_hud_scores()
	var players := get_players()
	var corners := [
		Vector2i(0, 0), Vector2i(GRID_SIZE - 1, 0),
		Vector2i(0, GRID_SIZE - 1), Vector2i(GRID_SIZE - 1, GRID_SIZE - 1)
	]
	for i in players.size():
		player_cursor[players[i].id] = corners[i % corners.size()]
	for _i in INITIAL_PYTHONS:
		_spawn_python()
	_python_timer = PYTHON_MOVE_INTERVAL
	_spawn_timer = SPAWN_INTERVAL

func _spawn_python() -> void:
	if _pythons.size() >= MAX_PYTHONS:
		return
	_pythons.append({
		"pos": Vector2i(randi() % GRID_SIZE, randi() % GRID_SIZE),
		"dir": DIRS[randi() % DIRS.size()],
		"alive": true,
	})

func on_tick(delta: float) -> void:
	_handle_input()
	_python_timer -= delta
	if _python_timer <= 0.0:
		_move_pythons()
		_python_timer = PYTHON_MOVE_INTERVAL
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_python()
		_spawn_timer = SPAWN_INTERVAL
	queue_redraw()

func _handle_input() -> void:
	for p in get_players():
		var pid: int = p.id
		var n := pid + 1
		var pos: Vector2i = player_cursor.get(pid, Vector2i.ZERO)
		if Input.is_action_just_pressed("player_%d_up" % n):
			pos.y -= 1
		elif Input.is_action_just_pressed("player_%d_down" % n):
			pos.y += 1
		elif Input.is_action_just_pressed("player_%d_left" % n):
			pos.x -= 1
		elif Input.is_action_just_pressed("player_%d_right" % n):
			pos.x += 1
		player_cursor[pid] = pos.clamp(Vector2i.ZERO, Vector2i(GRID_SIZE - 1, GRID_SIZE - 1))
		if Input.is_action_just_pressed("player_%d_action" % n):
			_place_trap(pid, player_cursor[pid])

func _place_trap(pid: int, pos: Vector2i) -> void:
	if _traps.has(pos):
		return
	_traps[pos] = pid

func _move_pythons() -> void:
	for python in _pythons:
		if not python.alive:
			continue
		if randf() < 0.25:
			python.dir = DIRS[randi() % DIRS.size()]
		var next: Vector2i = python.pos + python.dir
		if next.x < 0 or next.x >= GRID_SIZE or next.y < 0 or next.y >= GRID_SIZE:
			python.dir = DIRS[randi() % DIRS.size()]
			next = (python.pos + python.dir).clamp(Vector2i.ZERO, Vector2i(GRID_SIZE - 1, GRID_SIZE - 1))
		python.pos = next
		if _traps.has(next):
			var owner: int = _traps[next]
			add_score(owner, 1)
			_traps.erase(next)
			python.alive = false
	# Remove dead pythons
	var alive_pythons: Array = []
	for python in _pythons:
		if python.alive:
			alive_pythons.append(python)
	_pythons = alive_pythons

func _draw() -> void:
	var vp := get_viewport_rect().size
	var grid_px := CELL_SIZE * GRID_SIZE
	_grid_origin = (vp - Vector2(grid_px, grid_px)) / 2.0
	var font := ThemeDB.fallback_font

	# Grid
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			var col := GRID_EVEN if (x + y) % 2 == 0 else GRID_ODD
			draw_rect(Rect2(_grid_origin + Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE), col)

	# Traps
	for trap_pos: Vector2i in _traps:
		var owner: int = _traps[trap_pos]
		var trap_col := _get_player_color(owner)
		var origin := _grid_origin + Vector2(trap_pos) * CELL_SIZE
		draw_rect(Rect2(origin + Vector2(5, 5), Vector2.ONE * (CELL_SIZE - 10)), trap_col.darkened(0.4))
		draw_string(font, origin + Vector2(10, CELL_SIZE - 8),
			"[X]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, trap_col)

	# Pythons
	for python in _pythons:
		var origin: Vector2 = _grid_origin + Vector2(python.pos) * CELL_SIZE
		draw_rect(Rect2(origin + Vector2(4, 4), Vector2.ONE * (CELL_SIZE - 8)), PYTHON_COLOR)
		draw_string(font, origin + Vector2(8, CELL_SIZE - 8),
			"~", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.0, 0.3, 0.0))

	# Player cursors (outline only — players move the cursor, not a physical body)
	var players := get_players()
	for i in players.size():
		var pid: int = players[i].id
		var pos: Vector2i = player_cursor.get(pid, Vector2i.ZERO)
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		var origin := _grid_origin + Vector2(pos) * CELL_SIZE
		draw_rect(Rect2(origin, Vector2.ONE * CELL_SIZE), col, false, 3.0)

	# Legend
	draw_string(font, Vector2(8, vp.y - 10),
		"Move cursor  |  Action = place trap  |  Catch pythons for points",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _get_player_color(player_id: int) -> Color:
	var players := get_players()
	for i in players.size():
		if players[i].id == player_id:
			return PLAYER_COLORS[i % PLAYER_COLORS.size()]
	return Color.WHITE
