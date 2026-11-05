extends RefCounted

## A full six-headline party driven through real rebound keyboard events.

signal keycap_requested(text: String)
const Options = preload("res://games/florida_men/florida_men_options.gd")
const Match = preload("res://games/florida_men/model/party_match.gd")
const VERBS := ["up", "down", "left", "right", "action"]
const SEED := 745
var _held: Dictionary = {}
var _phase_key := ""
var _phase_time := 0.0
var _tapped := false
var _phase_times: Dictionary = {}


func configure(variant: String) -> bool:
	_held.clear()
	_phase_key = ""
	_phase_time = 0.0
	_tapped = false
	_phase_times.clear()
	return variant == "solo"


func duration() -> float:
	return 202.0


func capture_inset() -> float:
	return 275.0


func steps() -> Array[Dictionary]:
	return [
		{"time": 0.0, "title": "Four guests. Ten coins each.",
			"body": "One human plays with three CPU guests. Local setup also supports two, three or four humans."},
		{"time": 4.0, "title": "Roll around the boardwalk",
			"body": "Every guest rolls once. Tile marks show coin effects; only landing on GO pays its bonus."},
		{"time": 10.2, "title": "Alligator Wrangler: chase the toy",
			"body": "Move onto the gator's grid square. First to three wrangles wins; the gator gets quicker."},
		{"time": 16.4, "title": "Placement pays board coins",
			"body": "First / second / third / fourth pays 5 / 3 / 1 / 0 coins. Equal results share a placement."},
		{"time": 24.5, "title": "Rocket Man: hold to climb",
			"body": "Hold action for thrust. Release to fall. Everyone flies through the same cave; survive its gaps and edges."},
		{"time": 46.6, "title": "Hurricane Party: watch the labels",
			"body": "Move left or right. Ribboned +1 gifts score; wooden -1 debris costs a point. Only one guest catches each item."},
		{"time": 89.2, "title": "Python Hunt: leave catch crates",
			"body": "Move around the grid and tap action to place your colored crate. A toy python entering it earns you a point."},
		{"time": 132.5, "title": "Flamingo Fiasco: keep moving",
			"body": "Touch the birds to tag them. They scatter, then wander again. Most tags in thirty seconds wins."},
		{"time": 175.6, "title": "Lawnmower Race: choose a lane",
			"body": "Left or right changes lane. Mud, chickens and chairs slow your mower; first to the finish ends the race."},
		{"time": 191.0, "title": "Coins decide the holiday",
			"body": "Most board coins wins; minigame wins break ties. Completed parties pay Sunshine Tokens for hats. Share images link to the studio homepage."},
	]


func settings_overrides() -> Dictionary:
	return {Options.ROUNDS_KEY: 6, Options.CPU_KEY: 1, "ui/scale": 1.0}


func configure_session(session: Node) -> void:
	session.call("configure_single_player")


func start(scene: Node) -> void:
	(scene.get("_rng") as RandomNumberGenerator).seed = SEED
	scene.call("_start_round")


func update(scene: Node, time: float, delta: float) -> void:
	var party: RefCounted = scene.get("_match")
	var key := "%d:%d:%d" % [int(party.get("phase")), int(party.get("turn")), int(party.get("round_number"))]
	if key != _phase_key:
		_phase_key = key
		_phase_time = 0.0
		_tapped = false
		var phase := int(party.get("phase"))
		if phase == Match.Phase.MINIGAME:
			var game: String = party.call("current_game")
			_phase_times[game] = time
			print("Walkthrough: %s at %.2f s" % [game, time])
		elif phase == Match.Phase.STANDINGS:
			print("Walkthrough: standings %d at %.2f s" % [int(party.get("round_number")), time])
		elif phase == Match.Phase.FINISHED:
			_phase_times["finished"] = time
			print("Walkthrough: finished at %.2f s" % time)
	_phase_time += delta
	var command := {"dir": Vector2.ZERO, "action": false}
	if int(party.get("phase")) == Match.Phase.MINIGAME:
		var state: RefCounted = scene.get("_mini")
		command = state.call("suggested_input", 0)
	elif bool(scene.get("_round_active")):
		var phase := int(party.get("phase"))
		var roll_delay := 4.0 if int(party.get("round_number")) == 0 else 0.35
		var ready := phase == Match.Phase.BOARD and int(party.get("turn")) == 0 \
			and not bool(scene.get("_rolling")) and _phase_time >= roll_delay
		ready = ready or (phase == Match.Phase.BRIEFING and _phase_time >= 5.0) \
			or (phase == Match.Phase.STANDINGS and _phase_time >= 2.2)
		if ready and not _tapped:
			command["action"] = true
			_tapped = true
	_apply_keys(command)


func validate_finished(scene: Node) -> bool:
	_apply_keys({"dir": Vector2.ZERO, "action": false})
	var party: RefCounted = scene.get("_match")
	var valid := int(party.get("phase")) == Match.Phase.FINISHED \
		and (party.get("history") as Array).size() == 6 and _phase_times.size() == 7
	var hits: Array = scene.get("_total_hits")
	return valid and int(hits[0]) > 0


func _apply_keys(command: Dictionary) -> void:
	var direction: Vector2 = command["dir"]
	var desired := {
		"up": direction.y < -0.3, "down": direction.y > 0.3,
		"left": direction.x < -0.3, "right": direction.x > 0.3,
		"action": bool(command["action"]),
	}
	for verb: String in VERBS:
		var pressed := bool(desired[verb])
		if pressed == bool(_held.get(verb, false)):
			continue
		_held[verb] = pressed
		var action := Options.action(0, verb)
		for source in InputMap.action_get_events(action):
			if source is InputEventKey:
				var event := source.duplicate() as InputEventKey
				event.pressed = pressed
				event.echo = false
				Input.parse_input_event(event)
				if pressed:
					keycap_requested.emit(OS.get_keycode_string(event.physical_keycode))
				break
