extends RefCounted

## All six headline games use a fixed 120 Hz, node-free toy simulation.

const Data = preload("res://games/florida_men/data/party_data.gd")
const STEP := 1.0 / 120.0
const LIMIT := 30.0
const ARENA := Vector2(16.0, 10.0)
const DIRS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN,
]
const TRACK_LENGTH := 1000.0
const ROCKET_X := 2.0
const GAP := 2.65
const ROCKET_RADIUS := 0.18

var id := ""
var finished := false
var elapsed := 0.0
var scores: Array[int] = [0, 0, 0, 0]
var hits: Array[int] = [0, 0, 0, 0]
var misses: Array[int] = [0, 0, 0, 0]
var positions: Array[Vector2] = []
var velocity: Array[float] = [0.0, 0.0, 0.0, 0.0]
var progress: Array[float] = [0.0, 0.0, 0.0, 0.0]
var lanes: Array[int] = [1, 1, 1, 1]
var slow: Array[float] = [0.0, 0.0, 0.0, 0.0]
var alive: Array[bool] = [true, true, true, true]
var survival: Array[float] = [0.0, 0.0, 0.0, 0.0]
var gator := Vector2i(4, 4)
var entities: Array[Dictionary] = []
var obstacles: Array[Array] = []
var walls: Array[Dictionary] = []
var traps: Dictionary = {}
var cpu: Array[bool] = [false, false, false, false]
var difficulty := 1
var _rng := RandomNumberGenerator.new()
var _accumulator := 0.0
var _ticks := 0
var _timer := 0.0
var _spawn_timer := 0.0
var _gator_interval := 1.5
var _serial := 0
var _cooldown: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cpu_timer: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cpu_commands: Array[Dictionary] = []
var _held_action: Array[bool] = [false, false, false, false]
var _pending_action: Array[bool] = [false, false, false, false]
var _pending_move: Array[Vector2] = []
var _inputs: Array[Dictionary] = []
var _tag_cooldowns: Dictionary = {}


## World dimensions never depend on the window or its aspect ratio.
func configure(
	game: String, seed_value: int, cpu_seats: Array[bool], cpu_difficulty: int = 1
) -> void:
	Data.mini_game(game)
	assert(cpu_seats.size() == 4, "Every minigame needs four seat assignments.")
	id = game
	cpu = cpu_seats.duplicate()
	difficulty = clampi(cpu_difficulty, 0, 2)
	_rng.seed = seed_value
	finished = false
	elapsed = 0.0
	_accumulator = 0.0
	_ticks = 0
	_serial = 0
	_timer = 0.0
	_spawn_timer = 0.0
	_gator_interval = 1.5
	scores.fill(0)
	hits.fill(0)
	misses.fill(0)
	velocity.fill(0.0)
	progress.fill(0.0)
	lanes.fill(1)
	slow.fill(0.0)
	alive.fill(true)
	survival.fill(0.0)
	_cooldown.fill(0.0)
	_cpu_timer.fill(0.0)
	_held_action.fill(false)
	_pending_action.fill(false)
	positions.clear()
	_pending_move.clear()
	_inputs.clear()
	_cpu_commands.clear()
	entities.clear()
	obstacles.clear()
	walls.clear()
	traps.clear()
	_tag_cooldowns.clear()
	for player in 4:
		positions.append(Vector2.ZERO)
		_pending_move.append(Vector2.ZERO)
		_inputs.append({"dir": Vector2.ZERO, "action": false})
		_cpu_commands.append({"dir": Vector2.ZERO, "action": false})
	match id:
		"alligator_wrangler", "python_hunt":
			var edge := 7 if id == "alligator_wrangler" else 11
			positions.assign([
				Vector2.ZERO, Vector2(edge, 0), Vector2(0, edge), Vector2(edge, edge),
			])
			gator = Vector2i(4, 4)
			_timer = 1.5 if id == "alligator_wrangler" else 0.55
			if id == "python_hunt":
				for index in 4:
					_spawn_python()
				_spawn_timer = 7.0
		"lawnmower_race":
			var course: Array[Dictionary] = []
			for index in 12:
				course.append({
					"progress": _rng.randf_range(80.0, 950.0),
					"lane": _rng.randi_range(0, 2), "hit": false, "kind": index % 3,
				})
			for player in 4:
				obstacles.append(course.duplicate(true))
		"hurricane_party":
			for player in 4:
				positions[player] = Vector2(ARENA.x * (player + 1) / 5.0, 9.0)
			_spawn_timer = 0.55
		"rocket_man":
			for player in 4:
				positions[player] = Vector2(ROCKET_X, 5.0 + (player - 1.5) * 0.18)
			for index in 8:
				_spawn_wall(18.0 + index * 3.6)
		"flamingo_fiasco":
			positions.assign([Vector2(1, 1), Vector2(15, 1), Vector2(1, 9), Vector2(15, 9)])
			for index in 7:
				entities.append({
					"id": _next_id(), "pos": Vector2(
						_rng.randf_range(2.0, 14.0), _rng.randf_range(2.0, 8.0)),
					"vel": Vector2.from_angle(_rng.randf() * TAU) * 2.1,
					"timer": _rng.randf_range(0.3, 1.6),
				})


## Pulses survive render frames shorter than one physics tick.
func step(delta: float, commands: Array[Dictionary]) -> void:
	assert(is_finite(delta) and delta >= 0.0, "Invalid minigame delta.")
	assert(commands.size() == 4, "Every minigame needs four input snapshots.")
	if finished:
		return
	for player in 4:
		var command := commands[player]
		_inputs[player] = command.duplicate()
		var action := bool(command.get("action", false))
		_pending_action[player] = _pending_action[player] \
			or bool(command.get("tap", false)) or (action and not _held_action[player])
		_held_action[player] = action
		var tap: Vector2 = command.get("move_tap", Vector2.ZERO)
		if tap != Vector2.ZERO:
			_pending_move[player] = tap
	_accumulator += delta
	while _accumulator + 0.000000001 >= STEP and not finished:
		_accumulator -= STEP
		_ticks += 1
		elapsed = _ticks * STEP
		_tick()
		if _ticks >= roundi(LIMIT / STEP):
			finished = true


## A common descending metric feeds the party's placement and tie rules.
func metrics() -> Array[float]:
	var result: Array[float] = []
	for player in 4:
		match id:
			"lawnmower_race": result.append(progress[player])
			"rocket_man": result.append(LIMIT + 1.0 if alive[player] else survival[player])
			_: result.append(float(scores[player]))
	return result


## The same rule-aware steering drives CPU guests and the real-input walkthrough.
func suggested_input(player: int) -> Dictionary:
	var direction := Vector2.ZERO
	var action := false
	match id:
		"alligator_wrangler":
			direction = Vector2(gator) - positions[player]
		"lawnmower_race":
			var target := lanes[player]
			var nearest := INF
			for obstacle: Dictionary in obstacles[player]:
				var distance := float(obstacle["progress"]) - progress[player]
				if not obstacle["hit"] and distance > -25.0 and distance < 170.0 \
						and distance < nearest and int(obstacle["lane"]) == lanes[player]:
					nearest = distance
					target = (lanes[player] + 1) % 3
			direction.x = signf(target - lanes[player])
		"hurricane_party":
			var nearest := -INF
			for item in entities:
				var pos: Vector2 = item["pos"]
				if item["good"] and pos.y < nearest:
					continue
				if item["good"]:
					nearest = pos.y
					direction.x = signf(pos.x - positions[player].x) \
						if absf(pos.x - positions[player].x) > 0.25 else 0.0
			if direction == Vector2.ZERO:
				for item in entities:
					var pos: Vector2 = item["pos"]
					if not item["good"] and pos.y > 7.0 \
							and absf(pos.x - positions[player].x) < 0.8:
						direction.x = -1.0 if pos.x > ARENA.x * 0.5 else 1.0
		"rocket_man":
			var target := 5.0
			for wall in walls:
				if float(wall["x"]) >= ROCKET_X - 0.4:
					target = float(wall["gap"])
					break
			action = positions[player].y + velocity[player] * 0.34 > target
		"flamingo_fiasco":
			var nearest := INF
			for bird in entities:
				var pos: Vector2 = bird["pos"]
				var distance := positions[player].distance_squared_to(pos)
				if distance < nearest:
					nearest = distance
					direction = pos - positions[player]
		"python_hunt":
			var nearest := INF
			for python in entities:
				var target := Vector2(Vector2i(python["pos"]) + Vector2i(python["dir"]))
				target = target.clamp(Vector2.ZERO, Vector2(11, 11))
				if traps.has(Vector2i(target)):
					continue
				var distance := positions[player].distance_squared_to(target)
				if distance < nearest:
					nearest = distance
					direction = target - positions[player]
			action = direction.length_squared() < 0.5
	return {"dir": direction.normalized(), "action": action}


func _tick() -> void:
	for key: Vector2i in _tag_cooldowns.keys():
		_tag_cooldowns[key] = maxf(0.0, float(_tag_cooldowns[key]) - STEP)
	for player in 4:
		_cooldown[player] = maxf(0.0, _cooldown[player] - STEP)
		if cpu[player]:
			_cpu_timer[player] -= STEP
			if _cpu_timer[player] <= 0.0:
				_cpu_commands[player] = suggested_input(player)
				_cpu_timer[player] = [0.45, 0.24, 0.12][difficulty]
				if bool(_cpu_commands[player]["action"]):
					_pending_action[player] = true
			_inputs[player] = _cpu_commands[player]
	match id:
		"alligator_wrangler": _tick_gator()
		"lawnmower_race": _tick_mowers()
		"hurricane_party": _tick_party()
		"rocket_man": _tick_rockets()
		"flamingo_fiasco": _tick_flamingos()
		"python_hunt": _tick_pythons()
	_pending_action.fill(false)
	_pending_move.fill(Vector2.ZERO)


func _direction(player: int) -> Vector2:
	var direction: Vector2 = _inputs[player].get("dir", Vector2.ZERO)
	return direction.limit_length(1.0)


func _grid_move(player: int, edge: int) -> void:
	var direction := _direction(player)
	var pulse := _pending_move[player] != Vector2.ZERO
	if pulse:
		direction = _pending_move[player]
	if direction == Vector2.ZERO or (not pulse and _cooldown[player] > 0.0):
		return
	var move := Vector2(signf(direction.x), 0.0) if absf(direction.x) > absf(direction.y) \
		else Vector2(0.0, signf(direction.y))
	positions[player] = (positions[player] + move).clamp(Vector2.ZERO, Vector2(edge, edge))
	_cooldown[player] = 0.15


func _tick_gator() -> void:
	for player in 4:
		_grid_move(player, 7)
	_timer -= STEP
	if _timer <= 0.0:
		_move_gator()
		_timer += _gator_interval
	for player in 4:
		if Vector2i(positions[player]) == gator:
			_add_score(player, 1)
			_gator_interval = maxf(0.3, _gator_interval - 0.15)
			_move_gator()
	if scores.max() >= 3:
		finished = true


func _move_gator() -> void:
	var offset := _rng.randi_range(0, 3)
	for index in 4:
		var next := gator + DIRS[(offset + index) % 4]
		if next.x >= 0 and next.x < 8 and next.y >= 0 and next.y < 8:
			gator = next
			return


func _tick_mowers() -> void:
	for player in 4:
		var direction := _direction(player)
		if _pending_move[player] != Vector2.ZERO:
			direction = _pending_move[player]
			_cooldown[player] = 0.0
		if absf(direction.x) > 0.1 and _cooldown[player] <= 0.0:
			lanes[player] = clampi(lanes[player] + int(signf(direction.x)), 0, 2)
			_cooldown[player] = 0.18
		slow[player] = maxf(0.0, slow[player] - STEP)
		progress[player] = minf(TRACK_LENGTH,
			progress[player] + (60.0 if slow[player] > 0.0 else 200.0) * STEP)
		for obstacle: Dictionary in obstacles[player]:
			if not obstacle["hit"] and int(obstacle["lane"]) == lanes[player] \
					and absf(progress[player] - float(obstacle["progress"])) < 30.0:
				obstacle["hit"] = true
				slow[player] = 1.5
				misses[player] += 1
	if progress.max() >= TRACK_LENGTH:
		finished = true


func _tick_party() -> void:
	for player in 4:
		positions[player].x = clampf(
			positions[player].x + _direction(player).x * 5.8 * STEP, 0.4, ARENA.x - 0.4)
	_spawn_timer -= STEP
	if _spawn_timer <= 0.0:
		entities.append({
			"id": _next_id(), "pos": Vector2(_rng.randf_range(0.5, 15.5), -0.3),
			"good": _rng.randf() < 0.55,
		})
		_spawn_timer += 0.55
	for index in range(entities.size() - 1, -1, -1):
		var item := entities[index]
		var pos: Vector2 = item["pos"]
		pos.y += 3.5 * STEP
		item["pos"] = pos
		var caught := false
		for player in 4:
			if absf(pos.x - positions[player].x) < 0.65 and absf(pos.y - 9.0) < 0.45:
				_add_score(player, 1 if item["good"] else -1)
				caught = true
				break
		if caught or pos.y > 10.5:
			entities.remove_at(index)


func _tick_rockets() -> void:
	for wall in walls:
		wall["x"] = float(wall["x"]) - 2.92 * STEP
	while not walls.is_empty() and float(walls[0]["x"]) < -1.0:
		walls.pop_front()
	while walls.size() < 8:
		_spawn_wall(float(walls[-1]["x"]) + 3.6 if not walls.is_empty() else 18.0)
	for player in 4:
		if not alive[player]:
			continue
		var thrust := -10.0 if bool(_inputs[player].get("action", false)) else 0.0
		velocity[player] += (5.83 + thrust) * STEP
		positions[player].y += velocity[player] * STEP
		survival[player] = elapsed
		var collided := positions[player].y < ROCKET_RADIUS \
			or positions[player].y > ARENA.y - ROCKET_RADIUS
		for wall in walls:
			if absf(float(wall["x"]) - ROCKET_X) < 0.16 + ROCKET_RADIUS \
					and absf(positions[player].y - float(wall["gap"])) > GAP * 0.5 - ROCKET_RADIUS:
				collided = true
		if collided:
			alive[player] = false
			misses[player] += 1
	if alive.count(true) <= 1:
		finished = true


func _spawn_wall(x: float) -> void:
	walls.append({"id": _next_id(), "x": x, "gap": _rng.randf_range(2.4, 7.6)})


func _tick_flamingos() -> void:
	for player in 4:
		positions[player] = (positions[player] + _direction(player) * 4.1 * STEP).clamp(
			Vector2(0.3, 0.3), ARENA - Vector2(0.3, 0.3))
	for bird in entities:
		var pos: Vector2 = bird["pos"]
		var flee := Vector2.ZERO
		for player in 4:
			var difference := pos - positions[player]
			var distance := difference.length()
			if distance > 0.001 and distance < 1.8:
				flee += difference.normalized() * (1.8 - distance)
		var vel: Vector2 = bird["vel"]
		if flee.length() > 0.01:
			vel = flee.normalized() * 4.2
			bird["timer"] = 1.6
		else:
			bird["timer"] = float(bird["timer"]) - STEP
			if float(bird["timer"]) <= 0.0:
				vel = Vector2.from_angle(_rng.randf() * TAU) * 2.1
				bird["timer"] = _rng.randf_range(0.4, 1.6)
		pos += vel * STEP
		if pos.x < 0.25 or pos.x > 15.75:
			vel.x *= -1.0
		if pos.y < 0.25 or pos.y > 9.75:
			vel.y *= -1.0
		pos = pos.clamp(Vector2(0.25, 0.25), Vector2(15.75, 9.75))
		for player in 4:
			var key := Vector2i(player, int(bird["id"]))
			if positions[player].distance_to(pos) < 0.52 \
					and float(_tag_cooldowns.get(key, 0.0)) <= 0.0:
				_add_score(player, 1)
				_tag_cooldowns[key] = 0.4
				var away := (pos - positions[player]).normalized()
				if away == Vector2.ZERO:
					away = Vector2.RIGHT
				pos = (positions[player] + away * 0.75).clamp(
					Vector2(0.25, 0.25), Vector2(15.75, 9.75))
				vel = away * 6.3
				break
		bird["pos"] = pos
		bird["vel"] = vel


func _tick_pythons() -> void:
	for player in 4:
		_grid_move(player, 11)
		var tile := Vector2i(positions[player])
		if _pending_action[player] and not traps.has(tile):
			traps[tile] = player
	_timer -= STEP
	if _timer <= 0.0:
		_timer += 0.55
		for index in range(entities.size() - 1, -1, -1):
			var python := entities[index]
			var direction: Vector2i = python["dir"]
			if _rng.randf() < 0.25:
				direction = DIRS[_rng.randi_range(0, 3)]
			var next := Vector2i(python["pos"]) + direction
			if next.x < 0 or next.x >= 12 or next.y < 0 or next.y >= 12:
				direction = -direction
				next = (Vector2i(python["pos"]) + direction).clamp(
					Vector2i.ZERO, Vector2i(11, 11))
			python["pos"] = next
			python["dir"] = direction
			if traps.has(next):
				_add_score(int(traps[next]), 1)
				traps.erase(next)
				entities.remove_at(index)
	_spawn_timer -= STEP
	if _spawn_timer <= 0.0:
		_spawn_python()
		_spawn_timer += 7.0


func _spawn_python() -> void:
	if entities.size() < 18:
		entities.append({
			"id": _next_id(), "pos": Vector2i(_rng.randi_range(0, 11), _rng.randi_range(0, 11)),
			"dir": DIRS[_rng.randi_range(0, 3)],
		})


func _add_score(player: int, amount: int) -> void:
	scores[player] += amount
	if amount > 0:
		hits[player] += amount
	else:
		misses[player] -= amount


func _next_id() -> int:
	_serial += 1
	return _serial
