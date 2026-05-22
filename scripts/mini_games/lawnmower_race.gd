extends MiniGameBase

const TRACK_LENGTH := 1000.0
const BASE_SPEED := 200.0
const SLOW_SPEED := 60.0
const SLOW_DURATION := 1.5
const LANE_COUNT := 3
const OBSTACLE_COUNT := 12
const VIEW_SCALE := 0.5  # pixels per track unit visible on screen

const PLAYER_COLORS := [Color.CYAN, Color.YELLOW, Color.MAGENTA, Color.LIME_GREEN]
const OBS_COLOR := Color(0.85, 0.4, 0.1)

var player_progress: Dictionary = {}
var player_lanes: Dictionary = {}
var player_speed: Dictionary = {}
var player_slow_timer: Dictionary = {}
var player_obstacles: Dictionary = {}  # player_id -> Array[{progress, lane, hit}]
var _finish_order: Array = []

func setup() -> void:
	time_limit = 90.0
	for p in get_players():
		var pid: int = p.id
		player_progress[pid] = 0.0
		player_lanes[pid] = 1
		player_speed[pid] = BASE_SPEED
		player_slow_timer[pid] = 0.0
		player_obstacles[pid] = _generate_obstacles()

func _generate_obstacles() -> Array:
	var obs := []
	for _i in OBSTACLE_COUNT:
		obs.append({"progress": randf_range(80.0, TRACK_LENGTH - 50.0), "lane": randi() % LANE_COUNT, "hit": false})
	return obs

func on_tick(delta: float) -> void:
	_handle_input()
	_advance_players(delta)
	_check_collisions()
	queue_redraw()

func _handle_input() -> void:
	for p in get_players():
		var pid: int = p.id
		if pid in _finish_order:
			continue
		var n := pid + 1
		if Input.is_action_just_pressed("player_%d_left" % n):
			player_lanes[pid] = maxi(player_lanes.get(pid, 1) - 1, 0)
		elif Input.is_action_just_pressed("player_%d_right" % n):
			player_lanes[pid] = mini(player_lanes.get(pid, 1) + 1, LANE_COUNT - 1)

func _advance_players(delta: float) -> void:
	for p in get_players():
		var pid: int = p.id
		if pid in _finish_order:
			continue
		var slow_t: float = player_slow_timer.get(pid, 0.0) - delta
		player_slow_timer[pid] = slow_t
		if slow_t <= 0.0:
			player_speed[pid] = BASE_SPEED
		var prog: float = player_progress.get(pid, 0.0) + player_speed.get(pid, BASE_SPEED) * delta
		player_progress[pid] = prog
		if prog >= TRACK_LENGTH:
			_finish_order.append(pid)
			if _finish_order.size() >= get_players().size():
				end_game(build_results_from_order(_finish_order))
				return

func _check_collisions() -> void:
	for p in get_players():
		var pid: int = p.id
		if pid in _finish_order:
			continue
		var prog: float = player_progress.get(pid, 0.0)
		var lane: int = player_lanes.get(pid, 1)
		for obs in player_obstacles.get(pid, []):
			if obs.hit:
				continue
			if absf(prog - obs.progress) < 30.0 and lane == obs.lane:
				obs.hit = true
				player_speed[pid] = SLOW_SPEED
				player_slow_timer[pid] = SLOW_DURATION

func on_timeout() -> void:
	var remaining := []
	for p in get_players():
		if p.id not in _finish_order:
			remaining.append(p.id)
	remaining.sort_custom(func(a, b): return player_progress.get(a, 0.0) > player_progress.get(b, 0.0))
	end_game(build_results_from_order(_finish_order + remaining))

func _draw() -> void:
	var vp := get_viewport_rect().size
	var players := get_players()
	var n := maxi(players.size(), 1)
	var col_w := vp.x / n
	var lane_w := col_w / LANE_COUNT
	var player_y := vp.y - 70.0
	var font := ThemeDB.fallback_font

	for i in players.size():
		var pid: int = players[i].id
		var prog: float = player_progress.get(pid, 0.0)
		var lane: int = player_lanes.get(pid, 1)
		var col_x := i * col_w
		var p_color: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]

		# Lane backgrounds
		for l in LANE_COUNT:
			var bg := Color(0.14, 0.14, 0.14) if l == lane else Color(0.08, 0.08, 0.08)
			draw_rect(Rect2(col_x + l * lane_w, 0, lane_w, vp.y), bg)
			draw_line(Vector2(col_x + l * lane_w, 0), Vector2(col_x + l * lane_w, vp.y), Color(0.3, 0.3, 0.3))

		# Column separator
		draw_line(Vector2(col_x, 0), Vector2(col_x, vp.y), Color(0.5, 0.5, 0.5), 2.0)

		# Finish line
		var finish_y := player_y - (TRACK_LENGTH - prog) * VIEW_SCALE
		if finish_y > 0.0:
			draw_line(Vector2(col_x, finish_y), Vector2(col_x + col_w, finish_y), Color.WHITE, 3.0)
			draw_string(font, Vector2(col_x + 4, finish_y - 4), "FINISH",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

		# Obstacles
		for obs in player_obstacles.get(pid, []):
			if obs.hit:
				continue
			var obs_y: float = player_y - (obs.progress - prog) * VIEW_SCALE
			if obs_y < -20.0 or obs_y > vp.y + 20.0:
				continue
			var obs_x: float = col_x + obs.lane * lane_w
			draw_rect(Rect2(obs_x + 4, obs_y - 18, lane_w - 8, 36), OBS_COLOR)
			draw_string(font, Vector2(obs_x + 8, obs_y + 5), "OBS",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)

		# Player mower
		var p_lane_x := col_x + lane * lane_w
		draw_rect(Rect2(p_lane_x + 5, player_y - 22, lane_w - 10, 44), p_color)

		# Label + progress
		var pct := int(prog / TRACK_LENGTH * 100.0)
		draw_string(font, Vector2(col_x + 4, 20), "%s" % players[i].name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, p_color)
		draw_string(font, Vector2(col_x + 4, 36), "%d%%" % pct,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		if player_slow_timer.get(pid, 0.0) > 0.0:
			draw_string(font, Vector2(col_x + 4, 52), "SLOW!",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)
