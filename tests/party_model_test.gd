extends SceneTree

## Focused regressions for six rule sets, four input seats and complete-party rewards.

const Match = preload("res://games/florida_men/model/party_match.gd")
const Mini = preload("res://games/florida_men/model/mini_game_state.gd")
const Adapter = preload("res://games/florida_men/scripts/party_input.gd")
const Options = preload("res://games/florida_men/florida_men_options.gd")
const Data = preload("res://games/florida_men/data/party_data.gd")
const Sound = preload("res://games/florida_men/audio/party_sound.gd")
var _failures := PackedStringArray()
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_party()
	_test_gator()
	_test_mower()
	_test_party_items()
	_test_rocket()
	_test_flamingo()
	_test_python()
	_test_input()
	_test_determinism()
	_test_audio()
	for failure in _failures:
		printerr(failure)
	print("Florida Men model: %d checks, %d failures." % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _test_party() -> void:
	var party := Match.new()
	party.configure(3, 6, 735)
	_expect(party.coins == [10, 10, 10, 10] and party.is_cpu(3) and not party.is_cpu(2),
		"Three humans must leave only seat four to the CPU, with ten starting coins each.")
	var visited := {}
	for round_index in 6:
		visited[party.current_game()] = true
		for player in 4:
			var roll := party.roll()
			_expect(roll["player"] == player and roll["die"] >= 1 and roll["die"] <= 6,
				"Every board round must give each numbered seat one valid die.")
			_expect(party.positions[player] >= 0 and party.positions[player] < 24
				and party.coins[player] >= 0, "Board positions wrap and coins never go negative.")
			party.finish_board_turn()
		_expect(party.phase == Match.Phase.BRIEFING, "All four rolls must precede the briefing.")
		party.start_minigame()
		var before := party.coins.duplicate()
		party.finish_minigame([8.0, 8.0, 2.0, 0.0])
		var latest: Dictionary = party.history[-1]
		_expect(latest["placements"] == [0, 0, 2, 3]
			and latest["earned"] == [5, 5, 1, 0], "Ties share placement and do not favour P1.")
		_expect(party.coins[0] == before[0] + 5 and party.wins[0] == round_index + 1
			and party.wins[1] == round_index + 1, "Tied winners both receive their coins and win.")
		_expect(party.payout() == 0, "A standings screen is not yet a completed party payout.")
		party.advance()
	_expect(visited.size() == 6 and party.phase == Match.Phase.FINISHED,
		"A six-round party must visit every headline and then finish.")
	_expect(party.payout() > 0 and party.payout() <= 75, "Only a completed party pays bounded shop tokens.")
	party.coins.assign([30, 30, 29, 0])
	party.wins.assign([1, 2, 9, 0])
	_expect(party.winners() == [1], "Wins break equal coins, but cannot beat a higher coin total.")
	party.wins[0] = 2
	_expect(party.winners().size() == 2, "Equal coins and wins must remain a shared party win.")
	party.configure(1, 1, 43)
	var preview := RandomNumberGenerator.new()
	preview.seed = 123
	var die := preview.randi_range(1, 6)
	(party.get("_rng") as RandomNumberGenerator).seed = 123
	party.positions[0] = (24 - die) % 24
	party.roll()
	_expect(party.positions[0] == 0 and party.coins[0] == 13, "Landing on GO pays exactly three coins.")
	party.configure(1, 1, 43)
	(party.get("_rng") as RandomNumberGenerator).seed = 123
	party.positions[0] = posmod(3 - die, 24)
	party.coins[0] = 1
	party.roll()
	_expect(party.coins[0] == 0, "An unlucky tile cannot take coins below zero.")


func _test_gator() -> void:
	var state := _state("alligator_wrangler")
	state.gator = Vector2i(1, 0)
	var commands := _commands()
	commands[0] = {"dir": Vector2.RIGHT, "move_tap": Vector2.RIGHT}
	state.step(Mini.STEP, commands)
	_expect(state.scores[0] == 1 and state.positions[0] == Vector2(1, 0),
		"A real grid move onto the gator must wrangle it.")
	for capture in 2:
		state.positions[0] = Vector2(state.gator)
		state.step(Mini.STEP, _commands())
	_expect(state.finished and state.scores[0] == 3, "The third wrangle ends the minigame.")
	var frozen := state.metrics()
	state.step(10.0, _commands())
	_expect(state.metrics() == frozen, "An ended minigame cannot continue scoring.")


func _test_mower() -> void:
	var state := _state("lawnmower_race")
	for player in 4:
		state.obstacles[player].clear()
	state.obstacles[0].append({"progress": 42.0, "lane": 1, "hit": false, "kind": 0})
	state.step(0.1, _commands())
	var before := state.progress[0]
	state.step(0.1, _commands())
	_expect(state.misses[0] == 1 and state.progress[0] - before < 7.0,
		"A mower obstacle must slow its own driver and charge the bump only once.")
	_expect(state.progress[1] > state.progress[0], "Another driver's lane must not inherit that slow.")
	state.step(8.0, _commands())
	_expect(state.finished and state.progress.max() == Mini.TRACK_LENGTH, "The first finish ends the race.")


func _test_party_items() -> void:
	var state := _state("hurricane_party")
	state.entities.assign([
		{"id": 101, "pos": Vector2(state.positions[0].x, 8.6), "good": true},
		{"id": 102, "pos": Vector2(state.positions[1].x, 8.6), "good": false},
	])
	state.step(Mini.STEP, _commands())
	_expect(state.scores[0] == 1 and state.scores[1] == -1 and state.entities.is_empty(),
		"Gifts and debris must score +1/-1 and each be caught only once.")
	var commands := _commands()
	commands[3]["dir"] = Vector2.RIGHT
	state.step(5.0, commands)
	_expect(state.positions[3].x <= 15.6001, "Held catch movement must stay inside the authored arena.")


func _test_rocket() -> void:
	var state := _state("rocket_man")
	var commands := _commands()
	commands[0]["action"] = true
	state.step(0.2, commands)
	var thrust_velocity := state.velocity[0]
	_expect(state.positions[0].y < 4.73 and thrust_velocity < 0.0, "Held action must produce real upward thrust.")
	state.step(0.2, _commands())
	_expect(state.velocity[0] > thrust_velocity, "Releasing thrust restores downward gravity.")
	state = _state("rocket_man")
	state.walls.assign([{"id": 100, "x": Mini.ROCKET_X, "gap": 5.0}])
	state.positions[0].y = 9.0
	state.step(Mini.STEP, _commands())
	_expect(not state.alive[0] and state.alive[1], "A cave collision must eliminate only the colliding pilot.")
	state.alive.assign([false, false, false, true])
	state.step(Mini.STEP, _commands())
	_expect(state.finished and state.metrics()[3] > state.metrics()[0],
		"The last flying pilot must outrank eliminated pilots without inventing flight time.")


func _test_flamingo() -> void:
	var state := _state("flamingo_fiasco")
	state.entities.assign([{
		"id": 100, "pos": state.positions[0], "vel": Vector2.ZERO, "timer": 1.0,
	}])
	state.step(Mini.STEP, _commands())
	_expect(state.scores[0] == 1, "Touching a flamingo must tag it.")
	state.entities[0]["pos"] = state.positions[0]
	state.step(Mini.STEP, _commands())
	_expect(state.scores[0] == 1, "A tagged flamingo needs its cooldown before another point.")


func _test_python() -> void:
	var state := _state("python_hunt")
	state.entities.assign([{"id": 100, "pos": Vector2i(1, 0), "dir": Vector2i.LEFT}])
	state.set("_timer", 0.001)
	var commands := _commands()
	commands[0]["tap"] = true
	state.step(0.001, commands)
	state.step(0.01, _commands())
	_expect(state.scores[0] == 1 and state.entities.is_empty() and state.traps.is_empty(),
		"A short action pulse must place a crate, catch its entering python and consume the crate.")
	state = _state("python_hunt")
	state.step(30.0, _commands())
	_expect(state.finished and state.elapsed == 30.0 and state.entities.size() <= 18,
		"Python Hunt must stop at thirty model seconds and respect its population ceiling.")


func _test_input() -> void:
	var adapter := Adapter.new()
	for player in 4:
		var event := _key(Options.action(player, "right"), true)
		adapter.handle_event(event, 4, -1)
	var snapshots := adapter.snapshot()
	for player in 4:
		_expect(snapshots[player]["dir"] == Vector2.RIGHT, "Every seat must have independent real key input.")
	adapter.clear()
	adapter.set_touch(1, "left")
	adapter.set_touch(2, "action")
	adapter.set_touch(1, "")
	snapshots = adapter.snapshot()
	_expect(snapshots[0]["dir"] == Vector2.ZERO and snapshots[0]["action"],
		"Releasing one finger must not release another finger's thrust.")
	adapter.clear()
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	_expect(adapter.handle_event(press, 4, 3) == 3, "A fourth assigned pad must reach seat four.")
	snapshots = adapter.snapshot()
	_expect(snapshots[3]["action"] and not snapshots[0]["action"], "Pad input cannot leak into P1.")
	adapter.clear()
	adapter.handle_event(_key(Options.action(3, "action"), true), 4, -1)
	adapter.handle_event(_key(Options.action(3, "action"), false), 4, -1)
	snapshots = adapter.snapshot()
	_expect(snapshots[3]["tap"] and not snapshots[3]["action"], "A press/release between frames must retain its pulse.")
	adapter.clear()
	_expect(not adapter.snapshot()[3]["action"], "Phase/pause clears must release every input source.")


func _test_determinism() -> void:
	for entry in Data.MINI_GAMES:
		var one := Mini.new()
		var two := Mini.new()
		one.configure(entry["id"], 529, [true, true, true, true])
		two.configure(entry["id"], 529, [true, true, true, true])
		while not one.finished:
			one.step(1.0 / 30.0, _commands())
		while not two.finished:
			two.step(1.0 / 120.0, _commands())
		_expect(one.metrics() == two.metrics() and one.elapsed == two.elapsed,
			"%s must be deterministic across render rates." % entry["title"])
		_expect(one.finished and one.elapsed <= 30.0 and one.metrics().max() > 0.0,
			"%s must have rule-aware CPU guests that actually play and finish." % entry["title"])


func _test_audio() -> void:
	var music := Sound.music()
	_expect(not music.data.is_empty() and music.loop_end > 0
		and music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Original holiday music must be a playable loop.")
	for id in ["roll", "coin", "tag", "bump", "start", "finish"]:
		_expect(not Sound.cue(id).data.is_empty(), "Every semantic game cue needs actual audio.")


func _state(id: String) -> Mini:
	var state := Mini.new()
	state.configure(id, 17, [false, false, false, false])
	return state


func _commands() -> Array[Dictionary]:
	return [
		{"dir": Vector2.ZERO, "action": false}, {"dir": Vector2.ZERO, "action": false},
		{"dir": Vector2.ZERO, "action": false}, {"dir": Vector2.ZERO, "action": false},
	]


func _key(action: StringName, pressed: bool) -> InputEventKey:
	for source in InputMap.action_get_events(action):
		if source is InputEventKey:
			var result := source.duplicate() as InputEventKey
			result.pressed = pressed
			return result
	assert(false, "Missing declared keyboard action: " + action)
	return InputEventKey.new()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
