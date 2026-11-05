extends RefCounted

## Node-free party rules. Presentation never decides dice, rewards or standings.

const Data = preload("res://games/florida_men/data/party_data.gd")
enum Phase { BOARD, BRIEFING, MINIGAME, STANDINGS, FINISHED }
const PLACEMENT_POINTS := [3, 2, 1, 0]
const PLACEMENT_COINS := [5, 3, 1, 0]

var phase := Phase.BOARD
var humans := 1
var rounds := 10
var round_number := 0
var turn := 0
var positions: Array[int] = [0, 0, 0, 0]
var coins: Array[int] = [10, 10, 10, 10]
var points: Array[int] = [0, 0, 0, 0]
var wins: Array[int] = [0, 0, 0, 0]
var order: Array[String] = []
var history: Array[Dictionary] = []
var last_roll: Dictionary = {}
var _roll_pending := false
var _rng := RandomNumberGenerator.new()


## A seed reproduces the board and six-game rotation without global RNG state.
func configure(human_count: int, round_count: int, seed_value: int) -> void:
	assert(human_count >= 1 and human_count <= 4, "A party needs 1-4 humans.")
	assert(round_count > 0, "A party needs at least one minigame.")
	humans = human_count
	rounds = round_count
	round_number = 0
	turn = 0
	phase = Phase.BOARD
	positions.fill(0)
	coins.fill(10)
	points.fill(0)
	wins.fill(0)
	history.clear()
	last_roll.clear()
	_roll_pending = false
	_rng.seed = seed_value
	order.clear()
	for entry in Data.MINI_GAMES:
		order.append(str(entry["id"]))
	for index in range(order.size() - 1, 0, -1):
		var swap := _rng.randi_range(0, index)
		var old := order[index]
		order[index] = order[swap]
		order[swap] = old


## AI occupies only the seats not claimed by local humans.
func is_cpu(player: int) -> bool:
	return player >= humans


## Names stay numbered, including computer-controlled guests.
func player_name(player: int) -> String:
	return "CPU %d" % (player + 1) if is_cpu(player) else "Player %d" % (player + 1)


## Every six minigames visits each headline exactly once.
func current_game() -> String:
	return order[round_number % order.size()]


## A roll is charged once; animation must settle before the next seat rolls.
func roll() -> Dictionary:
	assert(phase == Phase.BOARD and not _roll_pending, "No board roll is available.")
	var die := _rng.randi_range(1, 6)
	var before := positions[turn]
	positions[turn] = (before + die) % Data.SPACE_TYPES.size()
	var type := Data.SPACE_TYPES[positions[turn]]
	var change := 0
	match type:
		0: change = 3
		2: change = 2
		3: change = -2
		4: change = _rng.randi_range(2, 4)
		5: change = -_rng.randi_range(1, 3)
	var old_coins := coins[turn]
	coins[turn] = maxi(0, old_coins + change)
	last_roll = {
		"player": turn, "from": before, "to": positions[turn], "die": die,
		"type": type, "change": coins[turn] - old_coins,
	}
	_roll_pending = true
	return last_roll.duplicate()


## Passing GO is not a landing; only a GO landing pays its three coins.
func finish_board_turn() -> void:
	assert(phase == Phase.BOARD and _roll_pending, "No roll is waiting to land.")
	_roll_pending = false
	turn += 1
	if turn == 4:
		phase = Phase.BRIEFING


## The briefing is player-paced rather than expiring while someone reads.
func start_minigame() -> void:
	assert(phase == Phase.BRIEFING, "A minigame must have a briefing.")
	phase = Phase.MINIGAME


## Tied metrics share a placement and reward; no seat wins a tie by array order.
func finish_minigame(metrics: Array[float]) -> void:
	assert(phase == Phase.MINIGAME and metrics.size() == 4, "Invalid minigame result.")
	var placements: Array[int] = []
	var earned: Array[int] = []
	for player in 4:
		var placement := 0
		for other in 4:
			if metrics[other] > metrics[player]:
				placement += 1
		placements.append(placement)
		earned.append(PLACEMENT_COINS[placement])
		coins[player] += PLACEMENT_COINS[placement]
		points[player] += PLACEMENT_POINTS[placement]
		if placement == 0:
			wins[player] += 1
	history.append({
		"game": current_game(), "metrics": metrics.duplicate(),
		"placements": placements, "earned": earned,
	})
	round_number += 1
	phase = Phase.STANDINGS


## Final results are reached only after the last standings have been accepted.
func advance() -> void:
	assert(phase == Phase.STANDINGS, "Only standings can advance the party.")
	turn = 0
	phase = Phase.FINISHED if round_number >= rounds else Phase.BOARD


## Coins decide the party; minigame wins are the sole tie-breaker.
func standings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in 4:
		result.append({
			"player": player, "name": player_name(player), "coins": coins[player],
			"wins": wins[player], "points": points[player], "cpu": is_cpu(player),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["coins"]) > int(b["coins"]) if a["coins"] != b["coins"] \
			else int(a["wins"]) > int(b["wins"])
	)
	return result


## A true coin-and-win tie has multiple winners.
func winners() -> Array[int]:
	var ranked := standings()
	var result: Array[int] = []
	for entry in ranked:
		if entry["coins"] == ranked[0]["coins"] and entry["wins"] == ranked[0]["wins"]:
			result.append(int(entry["player"]))
	return result


## Persistent shop tokens are separate from volatile board coins.
func payout() -> int:
	if phase != Phase.FINISHED:
		return 0
	var best := 0
	for player in humans:
		best = maxi(best, coins[player])
	return mini(75, 5 + floori(best * 0.5))
