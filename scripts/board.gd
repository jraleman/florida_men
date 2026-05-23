extends Control

# ── Enums ─────────────────────────────────────────────────────────────────────

enum SpaceType  { START, NORMAL, LUCKY, UNLUCKY, BONUS, PENALTY }
enum TurnState  { WAITING_FOR_ROLL, ROLLING, MOVING, SPACE_EFFECT, TRANSITION }

# ── Constants ─────────────────────────────────────────────────────────────────

const SPACE_COUNT         := 24
const DICE_ANIM_DURATION  := 0.9
const HOP_DURATION        := 0.18
const EFFECT_DURATION     := 1.8
const TRANSITION_DURATION := 0.4
const AI_ROLL_DELAY       := 0.85
const SPACE_SZ            := 64.0
const MARGIN              := 56.0

# Path layout: top(0-7), right-mid(8-11), bottom(12-19), left-mid(20-23)
# Values match SpaceType enum: 0=START 1=NORMAL 2=LUCKY 3=UNLUCKY 4=BONUS 5=PENALTY
const SPACE_TYPE_LIST: Array = [
	0, 2, 1, 3, 1, 4, 1, 5,   # top    0-7
	1, 2, 3, 1,                # right  8-11
	1, 2, 4, 1, 5, 1, 3, 1,   # bottom 12-19
	2, 1, 4, 5,                # left   20-23
]

const SPACE_COL: Array = [
	Color(0.10, 0.82, 0.15),   # START   bright green
	Color(0.22, 0.48, 0.88),   # NORMAL  blue
	Color(0.95, 0.78, 0.00),   # LUCKY   gold
	Color(0.88, 0.15, 0.15),   # UNLUCKY red
	Color(0.00, 0.80, 0.56),   # BONUS   teal
	Color(0.62, 0.08, 0.82),   # PENALTY purple
]

const SPACE_ICON: Array = [
	"GO", ".", "$", "!", "*", "X"
]

const SPACE_LABEL: Array = [
	"Start", "Normal", "Lucky", "Unlucky", "Bonus", "Penalty"
]

const PLAYER_COL: Array = [
	Color(1.00, 0.25, 0.25),
	Color(0.25, 0.52, 1.00),
	Color(0.18, 0.88, 0.18),
	Color(1.00, 0.76, 0.00),
]

# ── State ─────────────────────────────────────────────────────────────────────

var _spaces:         Array     = []
var _state:          TurnState = TurnState.WAITING_FOR_ROLL
var _player_order:   Array     = []
var _turn_idx:       int       = 0
var _dice_value:     int       = 1
var _dice_rolled:    bool      = false
var _dice_timer:     float     = 0.0
var _dice_cycle:     float     = 0.0
var _move_timer:     float     = 0.0
var _effect_timer:   float     = 0.0
var _trans_timer:    float     = 0.0
var _spaces_to_move: int       = 0
var _hops_done:      int       = 0
var _hop_from_idx:   int       = 0
var _hop_to_idx:     int       = 0
var _hop_progress:   float     = 0.0
var _effect_msg:     String    = ""
var _ai_delay:       float     = 0.0
var _board_done:     bool      = false

var _hud:        CanvasLayer
var _status_lbl: Label
var _effect_lbl: Label
var _coins_lbl:  Label

# ── Ready ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_spaces()
	_build_hud()
	_player_order.clear()
	for p: Dictionary in GameSession.players:
		_player_order.append(p.id)
	_begin_turn()

# ── Board layout ──────────────────────────────────────────────────────────────

func _build_spaces() -> void:
	_spaces.clear()
	var vp:    Vector2 = get_viewport_rect().size
	var right: float   = vp.x - MARGIN - SPACE_SZ
	var bot:   float   = vp.y - MARGIN - SPACE_SZ
	var xs:    float   = (right - MARGIN) / 7.0
	var ys:    float   = (bot   - MARGIN) / 5.0

	var pos_list: Array[Vector2] = []

	for i: int in 8:
		pos_list.append(Vector2(MARGIN + i * xs, MARGIN))

	for i: int in 4:
		pos_list.append(Vector2(right, MARGIN + (i + 1) * ys))

	for i: int in 8:
		pos_list.append(Vector2(right - i * xs, bot))

	for i: int in 4:
		pos_list.append(Vector2(MARGIN, bot - (i + 1) * ys))

	for i: int in SPACE_COUNT:
		_spaces.append({"type": SPACE_TYPE_LIST[i], "pos": pos_list[i]})

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	_status_lbl = Label.new()
	_status_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	_status_lbl.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	_status_lbl.set_anchor_and_offset(SIDE_TOP,    0.0,  6.0)
	_status_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 38.0)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_hud.add_child(_status_lbl)

	_effect_lbl = Label.new()
	_effect_lbl.set_anchor_and_offset(SIDE_LEFT,   0.1,  0.0)
	_effect_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.9,  0.0)
	_effect_lbl.set_anchor_and_offset(SIDE_TOP,    0.45, 0.0)
	_effect_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.6,  0.0)
	_effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_effect_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_effect_lbl.add_theme_font_size_override("font_size", 26)
	_effect_lbl.visible = false
	_hud.add_child(_effect_lbl)

	_coins_lbl = Label.new()
	_coins_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	_coins_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.22, 0.0)
	_coins_lbl.set_anchor_and_offset(SIDE_TOP,    0.0, 48.0)
	_coins_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	_coins_lbl.add_theme_font_size_override("font_size", 15)
	_hud.add_child(_coins_lbl)
	_refresh_coins_lbl()

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _board_done:
		return
	match _state:
		TurnState.WAITING_FOR_ROLL: _proc_waiting(delta)
		TurnState.ROLLING:          _proc_rolling(delta)
		TurnState.MOVING:           _proc_moving(delta)
		TurnState.SPACE_EFFECT:     _proc_effect(delta)
		TurnState.TRANSITION:       _proc_transition(delta)
	queue_redraw()

# ── Turn states ───────────────────────────────────────────────────────────────

func _begin_turn() -> void:
	_ai_delay  = 0.0
	_state     = TurnState.WAITING_FOR_ROLL
	_effect_lbl.visible = false
	var pid: int       = _player_order[_turn_idx]
	var pname: String  = _player_name(pid)
	if GameSession.is_ai_player(pid):
		_status_lbl.text = "%s is thinking..." % pname
	else:
		var action_key: String = _action_hint(pid)
		_status_lbl.text = "%s — Press %s to roll!" % [pname, action_key]

func _proc_waiting(delta: float) -> void:
	var pid: int = _player_order[_turn_idx]
	if GameSession.is_ai_player(pid):
		_ai_delay += delta
		if _ai_delay >= AI_ROLL_DELAY:
			_do_roll()
	else:
		if Input.is_action_just_pressed("player_%d_action" % (pid + 1)):
			_do_roll()

func _do_roll() -> void:
	var pname: String = _player_name(_player_order[_turn_idx])
	_status_lbl.text  = "%s is rolling..." % pname
	_dice_timer  = 0.0
	_dice_cycle  = 0.0
	_dice_rolled = true
	_state       = TurnState.ROLLING

func _proc_rolling(delta: float) -> void:
	_dice_timer += delta
	_dice_cycle += delta
	if _dice_cycle >= 0.07:
		_dice_cycle  = 0.0
		_dice_value  = randi_range(1, 6)
	if _dice_timer >= DICE_ANIM_DURATION:
		_dice_value     = randi_range(1, 6)
		_spaces_to_move = _dice_value
		_hops_done      = 0
		var pid: int    = _player_order[_turn_idx]
		var cur: int    = GameSession.board_positions.get(pid, 0)
		_hop_from_idx   = cur
		_hop_to_idx     = (cur + 1) % SPACE_COUNT
		_hop_progress   = 0.0
		_move_timer     = 0.0
		_status_lbl.text = "%s rolled a %d!" % [_player_name(pid), _dice_value]
		_state = TurnState.MOVING

func _proc_moving(delta: float) -> void:
	_move_timer   += delta
	_hop_progress  = minf(_move_timer / HOP_DURATION, 1.0)

	if _move_timer >= HOP_DURATION:
		_move_timer   = 0.0
		_hop_progress = 1.0
		var pid: int  = _player_order[_turn_idx]
		GameSession.board_positions[pid] = _hop_to_idx
		_hops_done += 1

		if _hops_done >= _spaces_to_move:
			var sp:    Dictionary = _spaces[_hop_to_idx]
			var stype: int        = sp["type"]
			_apply_space_effect(pid, stype)
			_effect_lbl.text    = _effect_msg
			_effect_lbl.visible = true
			_status_lbl.text    = ""
			_effect_timer       = 0.0
			_state              = TurnState.SPACE_EFFECT
		else:
			_hop_from_idx = _hop_to_idx
			_hop_to_idx   = (_hop_to_idx + 1) % SPACE_COUNT

func _proc_effect(delta: float) -> void:
	_effect_timer += delta
	if _effect_timer >= EFFECT_DURATION:
		_effect_lbl.visible = false
		_trans_timer        = 0.0
		_state              = TurnState.TRANSITION

func _proc_transition(delta: float) -> void:
	_trans_timer += delta
	if _trans_timer >= TRANSITION_DURATION:
		_turn_idx += 1
		if _turn_idx >= _player_order.size():
			_board_done = true
			GameSession.go_to("res://scenes/mini_game_selector.tscn")
		else:
			_begin_turn()

# ── Space effects ─────────────────────────────────────────────────────────────

func _apply_space_effect(player_id: int, space_type: int) -> void:
	var dc: int = 0
	match space_type:
		SpaceType.START:
			dc = 3
			_effect_msg = "Back at GO!  +3 Coins!"
		SpaceType.NORMAL:
			var opts: Array = [
				"Just another day in Florida...",
				"A gator nodded.  Nothing else.",
				"Someone nearby ate a tide pod.",
			]
			_effect_msg = opts[randi() % opts.size()]
		SpaceType.LUCKY:
			dc = 2
			_effect_msg = "Florida Sunshine!  +2 Coins!"
		SpaceType.UNLUCKY:
			dc = -2
			_effect_msg = "Gator Attack!  -2 Coins!"
		SpaceType.BONUS:
			dc = randi_range(2, 4)
			_effect_msg = "Florida Man SCORES!  +%d Coins!" % dc
		SpaceType.PENALTY:
			dc = -randi_range(1, 3)
			_effect_msg = "DUI Checkpoint!  %d Coins!" % dc
	if dc != 0:
		GameSession.add_board_coins(player_id, dc)
	_refresh_coins_lbl()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _player_name(player_id: int) -> String:
	for p: Dictionary in GameSession.players:
		if p.id == player_id:
			return p.name
	return "Player %d" % (player_id + 1)

func _action_hint(player_id: int) -> String:
	var keys: Array = ["Space", "Enter", "U", "Num0"]
	if player_id < keys.size():
		return keys[player_id]
	return "Action"

func _refresh_coins_lbl() -> void:
	var lines: Array = ["Coins:"]
	for p: Dictionary in GameSession.players:
		var pid: int   = p.id
		var coins: int = GameSession.board_coins.get(pid, 0)
		lines.append("  %s: %d" % [p.name, coins])
	_coins_lbl.text = "\n".join(PackedStringArray(lines))

func _get_token_visual_pos(player_id: int) -> Vector2:
	if _state == TurnState.MOVING:
		var mover: int = _player_order[_turn_idx]
		if mover == player_id:
			var sp_a: Dictionary = _spaces[_hop_from_idx]
			var sp_b: Dictionary = _spaces[_hop_to_idx]
			var pa: Vector2 = sp_a["pos"]
			var pb: Vector2 = sp_b["pos"]
			return pa.lerp(pb, _hop_progress)
	var idx: int        = GameSession.board_positions.get(player_id, 0)
	var sp:  Dictionary = _spaces[idx]
	var pos: Vector2    = sp["pos"]
	return pos

func _token_offset(player_id: int) -> Vector2:
	# Offset tokens so they don't overlap when sharing a space.
	var pid_pos: int    = GameSession.board_positions.get(player_id, 0)
	var same:    Array  = []
	for op in _player_order:
		var other: int = op
		if GameSession.board_positions.get(other, 0) == pid_pos:
			same.append(other)
	if same.size() <= 1:
		return Vector2.ZERO
	var offsets: Array[Vector2] = [
		Vector2(-10.0, -10.0), Vector2(10.0, -10.0),
		Vector2(-10.0,  10.0), Vector2(10.0,  10.0),
	]
	var i: int = same.find(player_id)
	if i < 0 or i >= offsets.size():
		return Vector2.ZERO
	return offsets[i]

func _pip_positions(value: int, center: Vector2, half: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var o: float = half * 0.65
	match value:
		1: result = [center]
		2: result = [center + Vector2(-o, -o), center + Vector2(o, o)]
		3: result = [center + Vector2(-o, -o), center, center + Vector2(o, o)]
		4: result = [
			center + Vector2(-o, -o), center + Vector2(o, -o),
			center + Vector2(-o,  o), center + Vector2(o,  o),
		]
		5: result = [
			center + Vector2(-o, -o), center + Vector2(o, -o), center,
			center + Vector2(-o,  o), center + Vector2(o,  o),
		]
		6: result = [
			center + Vector2(-o, -o), center + Vector2(-o, 0.0), center + Vector2(-o,  o),
			center + Vector2( o, -o), center + Vector2( o, 0.0), center + Vector2( o,  o),
		]
	return result

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	var vp:   Vector2 = get_viewport_rect().size
	var font: Font    = ThemeDB.fallback_font
	var cx:   float   = vp.x * 0.5
	var cy:   float   = vp.y * 0.5

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.16, 0.04))

	# Inner board area
	var itl: Vector2 = Vector2(MARGIN + SPACE_SZ + 4.0, MARGIN + SPACE_SZ + 4.0)
	var isz: Vector2 = vp - itl * 2.0
	draw_rect(Rect2(itl, isz), Color(0.07, 0.22, 0.07))
	draw_rect(Rect2(itl, isz), Color(0.15, 0.50, 0.15, 0.35), false, 2.0)

	# Center board info
	draw_string(font, Vector2(cx, cy - 52.0), "FLORIDA MEN",
		HORIZONTAL_ALIGNMENT_CENTER, 260.0, 30, Color(0.50, 1.00, 0.28))
	draw_string(font, Vector2(cx, cy - 16.0), "Round %d / %d" % [GameSession.round_number + 1, GameSession.ROUNDS_PER_MATCH],
		HORIZONTAL_ALIGNMENT_CENTER, 260.0, 18, Color(0.78, 0.92, 0.65))
	_draw_legend(font, cx, cy)

	# Path connections
	for i: int in SPACE_COUNT:
		var sp_a: Dictionary = _spaces[i]
		var sp_b: Dictionary = _spaces[(i + 1) % SPACE_COUNT]
		var pa:   Vector2    = sp_a["pos"]
		var pb:   Vector2    = sp_b["pos"]
		draw_line(pa + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5),
		          pb + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5),
		          Color(0.30, 0.48, 0.30, 0.65), 3.0)

	# Current-player space pulse
	if _state == TurnState.WAITING_FOR_ROLL or _state == TurnState.ROLLING:
		var pid: int        = _player_order[_turn_idx]
		var idx: int        = GameSession.board_positions.get(pid, 0)
		var sp:  Dictionary = _spaces[idx]
		var pos: Vector2    = sp["pos"]
		var t:   float      = fmod(Time.get_ticks_msec() * 0.003, TAU)
		draw_rect(Rect2(pos - Vector2(3.0, 3.0), Vector2(SPACE_SZ + 6.0, SPACE_SZ + 6.0)),
			Color(1.0, 1.0, 0.25, 0.38 + 0.35 * sin(t)), false, 3.5)

	# Spaces
	for i: int in SPACE_COUNT:
		var sp:    Dictionary = _spaces[i]
		var pos:   Vector2    = sp["pos"]
		var stype: int        = sp["type"]
		var col:   Color      = SPACE_COL[stype]
		var r:     Rect2      = Rect2(pos, Vector2(SPACE_SZ, SPACE_SZ))

		draw_rect(Rect2(pos + Vector2(3.0, 3.0), Vector2(SPACE_SZ, SPACE_SZ)), Color(0.0, 0.0, 0.0, 0.42))
		draw_rect(r, col)
		draw_rect(r, col.darkened(0.38), false, 2.0)
		draw_string(font, Vector2(pos.x, pos.y + SPACE_SZ * 0.58 + 5.0),
			SPACE_ICON[stype], HORIZONTAL_ALIGNMENT_CENTER, SPACE_SZ, 20, Color.WHITE)
		draw_string(font, Vector2(pos.x + 3.0, pos.y + 12.0),
			str(i), HORIZONTAL_ALIGNMENT_LEFT, SPACE_SZ, 10, Color(1.0, 1.0, 1.0, 0.62))

	# Player tokens
	for p: Dictionary in GameSession.players:
		var pid:    int     = p.id
		var vpos:   Vector2 = _get_token_visual_pos(pid)
		var pcol:   Color   = PLAYER_COL[mini(pid, PLAYER_COL.size() - 1)]
		var offset: Vector2 = _token_offset(pid)
		var center: Vector2 = vpos + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5) + offset

		draw_circle(center + Vector2(2.0, 2.0), 14.0, Color(0.0, 0.0, 0.0, 0.44))
		draw_circle(center, 14.0, pcol.darkened(0.22))
		draw_circle(center, 11.0, pcol)
		draw_arc(center, 11.5, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.55), 1.5)
		draw_string(font, Vector2(center.x, center.y + 5.0),
			str(pid + 1), HORIZONTAL_ALIGNMENT_CENTER, 28.0, 13, Color.WHITE)

	_draw_dice(vp, font)

func _draw_legend(font: Font, cx: float, cy: float) -> void:
	var types: Array = [SpaceType.LUCKY, SpaceType.UNLUCKY, SpaceType.BONUS, SpaceType.PENALTY, SpaceType.START]
	var labels: Array = ["Lucky +$", "Unlucky -$", "Bonus +$$", "Penalty -$", "GO +3"]
	var leg_y: float = cy + 28.0
	var leg_x: float = cx - (types.size() - 1) * 40.0
	for i: int in types.size():
		var col: Color = SPACE_COL[types[i]]
		draw_rect(Rect2(Vector2(leg_x + i * 80.0 - 10.0, leg_y - 10.0), Vector2(20.0, 20.0)), col)
		draw_string(font, Vector2(leg_x + i * 80.0, leg_y + 16.0),
			labels[i], HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11, Color(0.82, 0.92, 0.72))

func _draw_dice(vp: Vector2, font: Font) -> void:
	if not _dice_rolled or _state == TurnState.WAITING_FOR_ROLL:
		return
	var dsize: float   = 90.0
	var dcx:   float   = vp.x * 0.5
	# Sit above center so the effect label (at ~45% height) doesn't overlap
	var dcy:   float   = vp.y * 0.33
	var dtl:   Vector2 = Vector2(dcx - dsize * 0.5, dcy - dsize * 0.5)
	var dr:    Rect2   = Rect2(dtl, Vector2(dsize, dsize))

	# Rolling glow
	if _state == TurnState.ROLLING:
		var t: float = fmod(Time.get_ticks_msec() * 0.008, TAU)
		draw_rect(Rect2(dtl - Vector2(4.0, 4.0), Vector2(dsize + 8.0, dsize + 8.0)),
			Color(1.0, 0.9, 0.2, 0.4 + 0.3 * sin(t)))

	draw_rect(Rect2(dtl + Vector2(4.0, 4.0), Vector2(dsize, dsize)), Color(0.0, 0.0, 0.0, 0.38))
	draw_rect(dr, Color(0.96, 0.96, 0.94))
	draw_rect(dr, Color(0.22, 0.22, 0.22), false, 2.5)

	var pips: Array[Vector2] = _pip_positions(_dice_value, Vector2(dcx, dcy), dsize * 0.27)
	for pip: Vector2 in pips:
		draw_circle(pip, 6.5, Color(0.10, 0.10, 0.10))

	# Rolled value label below die
	draw_string(font, Vector2(dcx, dcy + dsize * 0.5 + 20.0),
		"Rolled: %d" % _dice_value, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 15,
		Color(0.9, 0.9, 0.7))
