extends MiniGameBase

const GRAVITY := 420.0
const THRUST := -720.0
const SCROLL_SPEED := 210.0
const GAP_HEIGHT := 190.0
const WALL_INTERVAL := 260.0
const WALL_WIDTH := 22.0
const PLAYER_RADIUS := 11.0
const PLAYER_X := 110.0

const PLAYER_COLORS := [Color.CYAN, Color.YELLOW, Color.MAGENTA, Color.LIME_GREEN]
const WALL_COLOR := Color(0.45, 0.22, 0.05)

var player_y: Dictionary = {}
var player_vy: Dictionary = {}
var player_alive: Dictionary = {}
var player_distance: Dictionary = {}
var _eliminated_order: Array = []
var _walls: Array = []  # {x, gap_y}

func setup() -> void:
	time_limit = 60.0
	var vp := get_viewport_rect().size
	var players := get_players()
	var y_start := vp.y / 2.0
	var spread := 20.0
	var offset := -(players.size() - 1) * spread / 2.0
	for i in players.size():
		var pid: int = players[i].id
		player_y[pid] = y_start + offset + i * spread
		player_vy[pid] = 0.0
		player_alive[pid] = true
		player_distance[pid] = 0.0
	_generate_walls()

func _generate_walls() -> void:
	var vp := get_viewport_rect().size
	var x := vp.x + 60.0
	for _i in 10:
		_walls.append({"x": x, "gap_y": randf_range(GAP_HEIGHT * 0.6, vp.y - GAP_HEIGHT * 0.6)})
		x += WALL_INTERVAL

func on_tick(delta: float) -> void:
	_update_walls(delta)
	_update_players(delta)
	queue_redraw()

func _update_players(delta: float) -> void:
	var vp := get_viewport_rect().size
	for p in get_players():
		var pid: int = p.id
		if not player_alive.get(pid, false):
			continue
		var n := pid + 1
		var vy: float = player_vy.get(pid, 0.0)
		if Input.is_action_pressed("player_%d_action" % n):
			vy += THRUST * delta
		vy += GRAVITY * delta
		var y: float = player_y.get(pid, 0.0) + vy * delta
		player_vy[pid] = vy
		player_y[pid] = y
		player_distance[pid] = player_distance.get(pid, 0.0) + SCROLL_SPEED * delta

		if y < PLAYER_RADIUS or y > vp.y - PLAYER_RADIUS:
			_eliminate(pid)
			continue

		for wall in _walls:
			var half_w := WALL_WIDTH / 2.0 + PLAYER_RADIUS
			if PLAYER_X + PLAYER_RADIUS > wall.x - half_w and PLAYER_X - PLAYER_RADIUS < wall.x + half_w:
				if absf(y - wall.gap_y) > GAP_HEIGHT / 2.0 - PLAYER_RADIUS:
					_eliminate(pid)
					break

func _eliminate(pid: int) -> void:
	if not player_alive.get(pid, false):
		return
	player_alive[pid] = false
	_eliminated_order.append(pid)
	var alive_count := 0
	for p in get_players():
		if player_alive.get(p.id, false):
			alive_count += 1
	if alive_count == 0:
		var rev := _eliminated_order.duplicate()
		rev.reverse()
		end_game(build_results_from_order(rev))

func _update_walls(delta: float) -> void:
	var vp := get_viewport_rect().size
	for wall in _walls:
		wall.x -= SCROLL_SPEED * delta
	var new_walls: Array = []
	for wall in _walls:
		if wall.x > -WALL_WIDTH:
			new_walls.append(wall)
	_walls = new_walls
	while _walls.size() < 10:
		var last_x := vp.x + 60.0
		if _walls.size() > 0:
			last_x = _walls[-1].x
		_walls.append({
			"x": last_x + WALL_INTERVAL,
			"gap_y": randf_range(GAP_HEIGHT * 0.6, vp.y - GAP_HEIGHT * 0.6)
		})

func on_timeout() -> void:
	var still_alive: Array = []
	for p in get_players():
		if player_alive.get(p.id, false):
			still_alive.append(p.id)
	still_alive.sort_custom(func(a, b): return player_distance.get(a, 0.0) > player_distance.get(b, 0.0))
	var rev_elim := _eliminated_order.duplicate()
	rev_elim.reverse()
	end_game(build_results_from_order(still_alive + rev_elim))

func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.04, 0.14))

	# Walls
	for wall in _walls:
		var top_h: float = wall.gap_y - GAP_HEIGHT / 2.0
		var bot_y: float = wall.gap_y + GAP_HEIGHT / 2.0
		draw_rect(Rect2(wall.x - WALL_WIDTH / 2.0, 0, WALL_WIDTH, top_h), WALL_COLOR)
		draw_rect(Rect2(wall.x - WALL_WIDTH / 2.0, bot_y, WALL_WIDTH, vp.y - bot_y), WALL_COLOR)

	# Players
	var players := get_players()
	for i in players.size():
		var pid: int = players[i].id
		var py: float = player_y.get(pid, vp.y / 2.0)
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		if not player_alive.get(pid, false):
			col = col.darkened(0.65)
		var x_offset := (i - (players.size() - 1) / 2.0) * 4.0
		draw_circle(Vector2(PLAYER_X + x_offset, py), PLAYER_RADIUS, col)
		if not player_alive.get(pid, false):
			draw_string(font, Vector2(PLAYER_X + x_offset - 6, py + 5),
				"X", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.RED)

	# Player labels (right side)
	for i in players.size():
		var pid: int = players[i].id
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		var status := "FLYING" if player_alive.get(pid, false) else "OUT"
		draw_string(font, Vector2(vp.x - 120, 20 + i * 22),
			"%s: %s" % [players[i].name, status],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

	draw_string(font, Vector2(8, vp.y - 10),
		"Hold action to thrust up", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
