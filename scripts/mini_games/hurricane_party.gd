extends MiniGameBase

const PLAYER_WIDTH := 48.0
const PLAYER_HEIGHT := 40.0
const PLAYER_SPEED := 320.0
const OBJECT_SPEED := 220.0
const OBJECT_RADIUS := 14.0
const SPAWN_INTERVAL := 0.55
const GOOD_CHANCE := 0.55

const PLAYER_COLORS := [Color.CYAN, Color.YELLOW, Color.MAGENTA, Color.LIME_GREEN]
const GOOD_COLOR := Color.GOLD
const BAD_COLOR := Color(0.55, 0.3, 0.1)

var player_x: Dictionary = {}
var _objects: Array = []  # {x, y, good}
var _spawn_timer: float = 0.0

func setup() -> void:
	time_limit = 45.0
	show_hud_scores()
	var vp := get_viewport_rect().size
	var players := get_players()
	var spacing := vp.x / (players.size() + 1)
	for i in players.size():
		player_x[players[i].id] = spacing * (i + 1)
	_spawn_timer = SPAWN_INTERVAL

func on_tick(delta: float) -> void:
	_handle_input(delta)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_object()
		_spawn_timer = SPAWN_INTERVAL
	_update_objects(delta)
	queue_redraw()

func _handle_input(delta: float) -> void:
	var vp := get_viewport_rect().size
	for p in get_players():
		var pid: int = p.id
		var n := pid + 1
		var x: float = player_x.get(pid, 0.0)
		if Input.is_action_pressed("player_%d_left" % n):
			x -= PLAYER_SPEED * delta
		if Input.is_action_pressed("player_%d_right" % n):
			x += PLAYER_SPEED * delta
		player_x[pid] = clampf(x, PLAYER_WIDTH / 2.0, vp.x - PLAYER_WIDTH / 2.0)

func _spawn_object() -> void:
	var vp := get_viewport_rect().size
	_objects.append({
		"x": randf_range(OBJECT_RADIUS + 4.0, vp.x - OBJECT_RADIUS - 4.0),
		"y": -OBJECT_RADIUS,
		"good": randf() < GOOD_CHANCE,
	})

func _update_objects(delta: float) -> void:
	var vp := get_viewport_rect().size
	var player_y := vp.y - 55.0
	var to_remove: Array = []

	for obj in _objects:
		obj.y += OBJECT_SPEED * delta
		if obj.y > vp.y + OBJECT_RADIUS:
			to_remove.append(obj)
			continue
		# Check catch by any player (each obj can only be caught once)
		for p in get_players():
			var pid: int = p.id
			var px: float = player_x.get(pid, 0.0)
			if absf(obj.x - px) < PLAYER_WIDTH / 2.0 + OBJECT_RADIUS \
					and absf(obj.y - player_y) < PLAYER_HEIGHT / 2.0 + OBJECT_RADIUS:
				add_score(pid, 1 if obj.good else -1)
				to_remove.append(obj)
				break

	for obj in to_remove:
		_objects.erase(obj)

func _draw() -> void:
	var vp := get_viewport_rect().size
	var player_y := vp.y - 55.0
	var font := ThemeDB.fallback_font

	# Ground
	draw_line(Vector2(0, player_y + PLAYER_HEIGHT / 2.0 + 2),
		Vector2(vp.x, player_y + PLAYER_HEIGHT / 2.0 + 2), Color(0.35, 0.35, 0.35), 2.0)

	# Falling objects
	for obj in _objects:
		var col: Color = GOOD_COLOR if obj.good else BAD_COLOR
		draw_circle(Vector2(obj.x, obj.y), OBJECT_RADIUS, col)
		var symbol: String = "+" if obj.good else "-"
		draw_string(font, Vector2(obj.x - 4, obj.y + 5), symbol,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)

	# Players
	var players := get_players()
	for i in players.size():
		var pid: int = players[i].id
		var px: float = player_x.get(pid, 0.0)
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		draw_rect(Rect2(px - PLAYER_WIDTH / 2.0, player_y - PLAYER_HEIGHT / 2.0, PLAYER_WIDTH, PLAYER_HEIGHT), col)
		var sc := get_score(pid)
		draw_string(font, Vector2(px - 24, player_y + PLAYER_HEIGHT / 2.0 + 18),
			"%s: %+d" % [players[i].name, sc], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

	draw_string(font, Vector2(8, vp.y - 8),
		"Catch party items (+)  Dodge debris (-)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
