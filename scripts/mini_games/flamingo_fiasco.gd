extends MiniGameBase

const PLAYER_SPEED := 230.0
const PLAYER_RADIUS := 16.0
const FLAMINGO_COUNT := 7
const FLAMINGO_RADIUS := 13.0
const FLAMINGO_BASE_SPEED := 120.0
const FLEE_RADIUS := 110.0
const WANDER_CHANGE_INTERVAL := 1.6
const TAG_COOLDOWN := 0.4  # seconds before a player can tag the same flamingo again

const PLAYER_COLORS := [Color.CYAN, Color.YELLOW, Color.MAGENTA, Color.LIME_GREEN]
const FLAMINGO_COLOR := Color(1.0, 0.65, 0.8)

var player_pos: Dictionary = {}
var _flamingos: Array = []  # {pos, vel, wander_timer, cooldowns}
var _tag_cooldowns: Dictionary = {}  # player_id -> {flamingo_index -> float}

func setup() -> void:
	time_limit = 30.0
	show_hud_scores()
	var vp := get_viewport_rect().size
	var players := get_players()
	var corners := [
		Vector2(60, 60), Vector2(vp.x - 60, 60),
		Vector2(60, vp.y - 60), Vector2(vp.x - 60, vp.y - 60)
	]
	for i in players.size():
		var pid: int = players[i].id
		player_pos[pid] = corners[i % corners.size()]
		_tag_cooldowns[pid] = {}
	for _i in FLAMINGO_COUNT:
		_flamingos.append({
			"pos": Vector2(randf_range(100, vp.x - 100), randf_range(100, vp.y - 100)),
			"vel": Vector2.from_angle(randf() * TAU) * FLAMINGO_BASE_SPEED,
			"wander_timer": randf_range(0.3, WANDER_CHANGE_INTERVAL),
		})

func on_tick(delta: float) -> void:
	_handle_input(delta)
	_update_flamingos(delta)
	_tick_cooldowns(delta)
	_check_tags()
	queue_redraw()

func _handle_input(delta: float) -> void:
	var vp := get_viewport_rect().size
	for p in get_players():
		var pid: int = p.id
		var n := pid + 1
		var dir := Vector2.ZERO
		if Input.is_action_pressed("player_%d_up" % n):    dir.y -= 1
		if Input.is_action_pressed("player_%d_down" % n):  dir.y += 1
		if Input.is_action_pressed("player_%d_left" % n):  dir.x -= 1
		if Input.is_action_pressed("player_%d_right" % n): dir.x += 1
		if dir != Vector2.ZERO:
			var pos: Vector2 = player_pos.get(pid, Vector2.ZERO) + dir.normalized() * PLAYER_SPEED * delta
			player_pos[pid] = pos.clamp(Vector2.ZERO, vp)

func _update_flamingos(delta: float) -> void:
	var vp := get_viewport_rect().size
	for f in _flamingos:
		var flee_dir := Vector2.ZERO
		for p in get_players():
			var pp: Vector2 = player_pos.get(p.id, Vector2.ZERO)
			var diff: Vector2 = f.pos - pp
			var dist := diff.length()
			if dist < FLEE_RADIUS and dist > 0.01:
				flee_dir += diff.normalized() * (FLEE_RADIUS - dist)
		if flee_dir.length() > 0.1:
			f.vel = flee_dir.normalized() * FLAMINGO_BASE_SPEED * 2.0
			f.wander_timer = WANDER_CHANGE_INTERVAL
		else:
			f.wander_timer -= delta
			if f.wander_timer <= 0.0:
				f.vel = Vector2.from_angle(randf() * TAU) * FLAMINGO_BASE_SPEED
				f.wander_timer = randf_range(0.4, WANDER_CHANGE_INTERVAL)
		f.pos += f.vel * delta
		if f.pos.x < FLAMINGO_RADIUS or f.pos.x > vp.x - FLAMINGO_RADIUS:
			f.vel.x *= -1.0
			f.pos.x = clampf(f.pos.x, FLAMINGO_RADIUS, vp.x - FLAMINGO_RADIUS)
		if f.pos.y < FLAMINGO_RADIUS or f.pos.y > vp.y - FLAMINGO_RADIUS:
			f.vel.y *= -1.0
			f.pos.y = clampf(f.pos.y, FLAMINGO_RADIUS, vp.y - FLAMINGO_RADIUS)

func _tick_cooldowns(delta: float) -> void:
	for pid in _tag_cooldowns:
		var cds: Dictionary = _tag_cooldowns[pid]
		for k in cds.keys():
			cds[k] -= delta
			if cds[k] <= 0.0:
				cds.erase(k)

func _check_tags() -> void:
	var tagged_this_frame: Array = []
	for p in get_players():
		var pid: int = p.id
		var pp: Vector2 = player_pos.get(pid, Vector2.ZERO)
		for fi in _flamingos.size():
			var f: Dictionary = _flamingos[fi]
			if fi in tagged_this_frame:
				continue
			if _tag_cooldowns[pid].has(fi):
				continue
			if pp.distance_to(f.pos) < PLAYER_RADIUS + FLAMINGO_RADIUS:
				add_score(pid, 1)
				tagged_this_frame.append(fi)
				_tag_cooldowns[pid][fi] = TAG_COOLDOWN
				var away: Vector2 = (f.pos - pp)
				if away.length() < 0.01:
					away = Vector2.from_angle(randf() * TAU)
				f.pos = pp + away.normalized() * (PLAYER_RADIUS + FLAMINGO_RADIUS + 12)
				f.vel = away.normalized() * FLAMINGO_BASE_SPEED * 3.0
				f.wander_timer = 0.8
				break

func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	# Flamingos
	for f in _flamingos:
		draw_circle(f.pos, FLAMINGO_RADIUS, FLAMINGO_COLOR)
		draw_circle(f.pos, FLAMINGO_RADIUS, Color(0.9, 0.4, 0.6), false, 2.0)

	# Players
	var players := get_players()
	for i in players.size():
		var pid: int = players[i].id
		var col: Color = PLAYER_COLORS[i % PLAYER_COLORS.size()]
		var pos: Vector2 = player_pos.get(pid, Vector2.ZERO)
		draw_circle(pos, PLAYER_RADIUS, col)
		draw_string(font, pos + Vector2(-20, -PLAYER_RADIUS - 4),
			players[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

	draw_string(font, Vector2(8, vp.y - 10),
		"Tag the flamingos for points!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
