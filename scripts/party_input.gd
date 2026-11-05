extends RefCounted

## One input snapshot per seat, without injecting CPU actions into InputMap.

const Options = preload("res://games/florida_men/florida_men_options.gd")
const VERBS := ["up", "down", "left", "right", "action"]
var _keys: Array[Dictionary] = [{}, {}, {}, {}]
var _pads: Array[Dictionary] = [{}, {}, {}, {}]
var _sticks: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _taps: Array[bool] = [false, false, false, false]
var _moves: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _touches: Dictionary = {}


## Returns the seat whose action was newly pressed, or -1.
func handle_event(event: InputEvent, humans: int, pad_player: int) -> int:
	var action_player := -1
	if event is InputEventKey:
		if event.echo:
			return -1
		for player in humans:
			for verb: String in VERBS:
				if event.is_action(Options.action(player, verb)):
					var was_held := bool(_keys[player].get(verb, false))
					_keys[player][verb] = event.pressed
					if event.pressed and not was_held:
						_mark_press(player, verb)
						if verb == "action":
							action_player = player
	elif pad_player >= 0 and pad_player < humans:
		if event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_LEFT_X:
				_sticks[pad_player].x = event.axis_value if absf(event.axis_value) > 0.22 else 0.0
			elif event.axis == JOY_AXIS_LEFT_Y:
				_sticks[pad_player].y = event.axis_value if absf(event.axis_value) > 0.22 else 0.0
		elif event is InputEventJoypadButton:
			var buttons := {
				JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down",
				JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right",
				JOY_BUTTON_A: "action",
			}
			if buttons.has(event.button_index):
				var verb: String = buttons[event.button_index]
				var was_held := bool(_pads[pad_player].get(verb, false))
				_pads[pad_player][verb] = event.pressed
				if event.pressed and not was_held:
					_mark_press(pad_player, verb)
					if verb == "action":
						action_player = pad_player
	return action_player


## Finger ids are independent; releasing a direction never releases thrust.
func set_touch(finger: int, verb: String) -> bool:
	var previous := str(_touches.get(finger, ""))
	if verb.is_empty():
		_touches.erase(finger)
	else:
		_touches[finger] = verb
	if verb != previous and not verb.is_empty():
		_mark_press(0, verb)
		return verb == "action"
	return false


## Consumes pulses, not held state. The model buffers them until its next tick.
func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in 4:
		var held := _keys[player].duplicate()
		for verb: String in _pads[player]:
			held[verb] = bool(held.get(verb, false)) or bool(_pads[player][verb])
		if player == 0:
			for verb: String in _touches.values():
				held[verb] = true
		var direction := Vector2(
			float(held.get("right", false)) - float(held.get("left", false)),
			float(held.get("down", false)) - float(held.get("up", false))
		) + _sticks[player]
		result.append({
			"dir": direction.limit_length(1.0), "action": bool(held.get("action", false)),
			"tap": _taps[player], "move_tap": _moves[player],
		})
	_taps.fill(false)
	_moves.fill(Vector2.ZERO)
	return result


## Phase changes, pauses and unplugged controllers cannot leave held input behind.
func clear() -> void:
	for player in 4:
		_keys[player].clear()
		_pads[player].clear()
	_sticks.fill(Vector2.ZERO)
	_taps.fill(false)
	_moves.fill(Vector2.ZERO)
	_touches.clear()


func _mark_press(player: int, verb: String) -> void:
	if verb == "action":
		_taps[player] = true
	else:
		_moves[player] = {
			"up": Vector2.UP, "down": Vector2.DOWN,
			"left": Vector2.LEFT, "right": Vector2.RIGHT,
		}[verb]
