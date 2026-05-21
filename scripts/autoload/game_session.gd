extends Node

const MAX_PLAYERS := 4
const ROUNDS_PER_MATCH := 6
const PLACEMENT_POINTS := [3, 2, 1, 0]

const MINI_GAMES := [
	"res://scenes/mini_games/alligator_wrangler.tscn",
	"res://scenes/mini_games/lawnmower_race.tscn",
	"res://scenes/mini_games/hurricane_party.tscn",
	"res://scenes/mini_games/rocket_man.tscn",
	"res://scenes/mini_games/flamingo_fiasco.tscn",
	"res://scenes/mini_games/python_hunt.tscn",
]

const MINI_GAME_DATA := {
	"res://scenes/mini_games/alligator_wrangler.tscn": {
		"name": "Alligator Wrangler",
		"rules": [
			"Move your cursor onto the gator to wrangle it.",
			"The gator speeds up after each wrangle.",
			"First player to wrangle 3 times wins.",
		]
	},
	"res://scenes/mini_games/lawnmower_race.tscn": {
		"name": "Lawnmower Race",
		"rules": [
			"Race your lawnmower from start to finish.",
			"Obstacles (mud, chickens, chairs) slow you down.",
			"First to cross the finish line wins.",
		]
	},
	"res://scenes/mini_games/hurricane_party.tscn": {
		"name": "Hurricane Party",
		"rules": [
			"Move left and right to catch falling objects.",
			"Party items: +1 pt  |  Debris: -1 pt",
			"Highest score when the timer ends wins.",
		]
	},
	"res://scenes/mini_games/rocket_man.tscn": {
		"name": "Rocket Man",
		"rules": [
			"Hold action to thrust up, release to fall.",
			"Avoid the cave walls as they scroll past.",
			"Last player still flying wins.",
		]
	},
	"res://scenes/mini_games/flamingo_fiasco.tscn": {
		"name": "Flamingo Fiasco",
		"rules": [
			"Move into flamingos to tag them for a point.",
			"Flamingos scatter when tagged.",
			"Most tags when the timer ends wins.",
		]
	},
	"res://scenes/mini_games/python_hunt.tscn": {
		"name": "Python Hunt",
		"rules": [
			"Place traps on grid tiles.",
			"Score a point when a python walks into your trap.",
			"Pythons multiply over time — most points wins.",
		]
	},
}

var players: Array = []
var scores: Dictionary = {}
var round_number: int = 0
var mini_game_order: Array = []
var _mini_game_index: int = 0
var last_round_winner_id: int = -1
var last_round_points: Dictionary = {}

func _ready() -> void:
	_setup_input_actions()

func _setup_input_actions() -> void:
	# [up, down, left, right, action] per player
	var bindings := [
		[KEY_W,      KEY_S,       KEY_A,      KEY_D,      KEY_SPACE],
		[KEY_UP,     KEY_DOWN,    KEY_LEFT,   KEY_RIGHT,  KEY_ENTER],
		[KEY_I,      KEY_K,       KEY_J,      KEY_L,      KEY_U],
		[KEY_KP_8,   KEY_KP_2,   KEY_KP_4,   KEY_KP_6,   KEY_KP_0],
	]
	var suffixes := ["up", "down", "left", "right", "action"]

	for i in MAX_PLAYERS:
		for j in suffixes.size():
			var action_name := "player_%d_%s" % [i + 1, suffixes[j]]
			if not InputMap.has_action(action_name):
				InputMap.add_action(action_name)
			else:
				InputMap.action_erase_events(action_name)
			var ev := InputEventKey.new()
			ev.physical_keycode = bindings[i][j]
			InputMap.action_add_event(action_name, ev)

func add_player(player_id: int) -> void:
	if player_id >= MAX_PLAYERS:
		return
	for p in players:
		if p.id == player_id:
			return
	players.append({"id": player_id, "name": "Player %d" % (player_id + 1)})
	scores[player_id] = 0

func remove_player(player_id: int) -> void:
	for i in range(players.size() - 1, -1, -1):
		if players[i].id == player_id:
			players.remove_at(i)
			break
	scores.erase(player_id)

func clear_session() -> void:
	players.clear()
	scores.clear()
	round_number = 0
	_mini_game_index = 0
	mini_game_order.clear()
	last_round_winner_id = -1
	last_round_points.clear()

func start_match() -> void:
	round_number = 0
	_mini_game_index = 0
	mini_game_order = MINI_GAMES.duplicate()
	mini_game_order.shuffle()
	last_round_winner_id = -1
	last_round_points.clear()
	for p in players:
		scores[p.id] = 0

func get_current_mini_game_scene() -> String:
	return mini_game_order[_mini_game_index % mini_game_order.size()]

func get_current_mini_game_name() -> String:
	var path := get_current_mini_game_scene()
	var data: Dictionary = MINI_GAME_DATA.get(path, {})
	return data.get("name", path.get_file().get_basename().replace("_", " ").capitalize())

func get_current_mini_game_rules() -> Array:
	var path := get_current_mini_game_scene()
	var data: Dictionary = MINI_GAME_DATA.get(path, {})
	return data.get("rules", [])

func apply_results(results: Array) -> void:
	# results: Array of {player_id, placement} where placement 0 = first place
	last_round_points.clear()
	last_round_winner_id = -1
	for entry in results:
		var pts: int = PLACEMENT_POINTS[mini(entry.placement, PLACEMENT_POINTS.size() - 1)]
		last_round_points[entry.player_id] = pts
		scores[entry.player_id] += pts
		if entry.placement == 0:
			last_round_winner_id = entry.player_id
	_mini_game_index += 1
	round_number += 1

func is_match_over() -> bool:
	return round_number >= ROUNDS_PER_MATCH

func get_sorted_scores() -> Array:
	var result := []
	for p in players:
		result.append({"id": p.id, "name": p.name, "score": scores.get(p.id, 0)})
	result.sort_custom(func(a, b): return a.score > b.score)
	return result

func get_last_round_winner_name() -> String:
	if last_round_winner_id == -1:
		return ""
	for p in players:
		if p.id == last_round_winner_id:
			return p.name
	return ""

func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
