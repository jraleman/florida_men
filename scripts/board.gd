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

# ── Scene refs ────────────────────────────────────────────────────────────────

@onready var sub_viewport:      SubViewport    = $SubViewportContainer/SubViewport
@onready var landing_particles: CPUParticles2D = $LandingParticles

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
var _rng:            RandomNumberGenerator

var _hud:        CanvasLayer
var _status_lbl: Label
var _effect_lbl: Label
var _effect_bg:  ColorRect
var _coins_lbl:  Label

var _board_root: Node3D = null

# ── Ready ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_setup_3d_scene()
	_setup_landing_particles()
	_build_spaces()
	_build_hud()
	_player_order.clear()
	for p: Dictionary in GameSession.players:
		_player_order.append(p.id)
	_begin_turn()

# ── 3D backdrop ───────────────────────────────────────────────────────────────

func _setup_3d_scene() -> void:
	# Near-top-down camera with slight tilt for depth
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 2.5)
	cam.rotation_degrees = Vector3(-76, 0, 0)
	sub_viewport.add_child(cam)

	# Florida daytime sky
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.68, 0.98)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.95, 1.0)
	env.ambient_light_energy = 3.2
	world_env.environment = env
	sub_viewport.add_child(world_env)

	# Sun
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 22, 0)
	sun.light_color = Color(1.0, 0.92, 0.65)
	sun.light_energy = 3.0
	sun.shadow_enabled = false
	sub_viewport.add_child(sun)

	# Fill light from the blue sky side
	var fill := OmniLight3D.new()
	fill.position = Vector3(-5, 6, 0)
	fill.light_color = Color(0.40, 0.65, 1.0)
	fill.light_energy = 1.8
	fill.omni_range = 20.0
	sub_viewport.add_child(fill)

	_board_root = Node3D.new()
	sub_viewport.add_child(_board_root)

	# Ocean surrounding the island
	_make_3d_box(_board_root, Vector3(0, -1.2, 0), Vector3(28, 0.8, 18),
			Color(0.14, 0.52, 0.88), 0.12, 0.50)
	# Florida island (green landmass)
	_make_3d_box(_board_root, Vector3(0, -0.6, 0), Vector3(19, 0.8, 12),
			Color(0.20, 0.62, 0.20), 0.05, 0.80)
	# Inner terrain (raised slightly, lighter)
	_make_3d_box(_board_root, Vector3(0, -0.2, 0), Vector3(11.5, 0.5, 7.5),
			Color(0.30, 0.74, 0.28), 0.04, 0.78)

	# Corner palm trees
	for corner in [Vector3(-8, 0, -4.5), Vector3(8, 0, -4.5),
				   Vector3(-8, 0, 4.5),  Vector3(8, 0, 4.5)]:
		_make_palm(_board_root, corner)

	# Mid-side palms for extra depth
	_make_palm(_board_root, Vector3(-9, 0, 0))
	_make_palm(_board_root, Vector3(9, 0, 0))

func _make_3d_box(parent: Node3D, pos: Vector3, sz: Vector3, color: Color,
		metallic: float, roughness: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _make_palm(parent: Node3D, pos: Vector3) -> void:
	# Trunk
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 2.2
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.18
	trunk.mesh = cyl
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.50, 0.34, 0.14)
	trunk_mat.emission_enabled = true
	trunk_mat.emission = Color(0.50, 0.34, 0.14)
	trunk_mat.emission_energy_multiplier = 1.0
	trunk.material_override = trunk_mat
	trunk.position = pos + Vector3(0, 0.7, 0)
	parent.add_child(trunk)

	# Foliage
	var top := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.75
	sph.height = 1.1
	top.mesh = sph
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.10, 0.60, 0.14)
	top_mat.emission_enabled = true
	top_mat.emission = Color(0.10, 0.60, 0.14)
	top_mat.emission_energy_multiplier = 1.4
	top.material_override = top_mat
	top.position = pos + Vector3(0, 2.1, 0)
	parent.add_child(top)

# ── Landing particles ─────────────────────────────────────────────────────────

func _setup_landing_particles() -> void:
	landing_particles.amount = 60
	landing_particles.lifetime = 1.6
	landing_particles.one_shot = true
	landing_particles.explosiveness = 0.92
	landing_particles.emitting = false
	landing_particles.gravity = Vector2(0, 280)
	landing_particles.initial_velocity_min = 85.0
	landing_particles.initial_velocity_max = 230.0
	landing_particles.direction = Vector2(0, -1)
	landing_particles.spread = 65.0
	landing_particles.angular_velocity_min = -180.0
	landing_particles.angular_velocity_max = 180.0
	landing_particles.scale_amount_min = 4.0
	landing_particles.scale_amount_max = 10.0

func _spawn_landing_particles(space_idx: int, space_type: int) -> void:
	var sp: Dictionary = _spaces[space_idx]
	var pos: Vector2 = sp["pos"]
	landing_particles.position = pos + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5)
	landing_particles.color = SPACE_COL[space_type]
	landing_particles.amount = 30 if space_type == SpaceType.NORMAL else 90
	landing_particles.restart()

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

	var status_bg := ColorRect.new()
	status_bg.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	status_bg.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	status_bg.set_anchor_and_offset(SIDE_TOP,    0.0,  0.0)
	status_bg.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 44.0)
	status_bg.color = Color(0.0, 0.05, 0.0, 0.72)
	_hud.add_child(status_bg)

	_status_lbl = Label.new()
	_status_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	_status_lbl.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	_status_lbl.set_anchor_and_offset(SIDE_TOP,    0.0,  6.0)
	_status_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 42.0)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 20)
	_status_lbl.add_theme_color_override("font_color", Color(0.92, 1.00, 0.80, 1))
	_hud.add_child(_status_lbl)

	_effect_bg = ColorRect.new()
	_effect_bg.set_anchor_and_offset(SIDE_LEFT,   0.08, 0.0)
	_effect_bg.set_anchor_and_offset(SIDE_RIGHT,  0.92, 0.0)
	_effect_bg.set_anchor_and_offset(SIDE_TOP,    0.43, 0.0)
	_effect_bg.set_anchor_and_offset(SIDE_BOTTOM, 0.62, 0.0)
	_effect_bg.color = Color(0.0, 0.0, 0.0, 0.72)
	_effect_bg.visible = false
	_hud.add_child(_effect_bg)

	_effect_lbl = Label.new()
	_effect_lbl.set_anchor_and_offset(SIDE_LEFT,   0.10, 0.0)
	_effect_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.90, 0.0)
	_effect_lbl.set_anchor_and_offset(SIDE_TOP,    0.44, 0.0)
	_effect_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.61, 0.0)
	_effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_effect_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_effect_lbl.add_theme_font_size_override("font_size", 28)
	_effect_lbl.add_theme_color_override("font_color", Color(1.00, 0.95, 0.55, 1))
	_effect_lbl.visible = false
	_hud.add_child(_effect_lbl)

	var coins_bg := ColorRect.new()
	coins_bg.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	coins_bg.set_anchor_and_offset(SIDE_RIGHT,  0.20, 0.0)
	coins_bg.set_anchor_and_offset(SIDE_TOP,    0.0, 44.0)
	coins_bg.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	coins_bg.color = Color(0.0, 0.05, 0.0, 0.68)
	_hud.add_child(coins_bg)

	_coins_lbl = Label.new()
	_coins_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	_coins_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.20, 0.0)
	_coins_lbl.set_anchor_and_offset(SIDE_TOP,    0.0, 52.0)
	_coins_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	_coins_lbl.add_theme_font_size_override("font_size", 15)
	_coins_lbl.add_theme_color_override("font_color", Color(0.82, 0.98, 0.65, 1))
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
	_effect_bg.visible  = false
	if _player_order.is_empty():
		return
	var pid: int       = _player_order[_turn_idx]
	var pname: String  = _player_name(pid)
	if GameSession.is_ai_player(pid):
		_status_lbl.text = "%s is thinking..." % pname
	else:
		var action_key: String = _action_hint(pid)
		_status_lbl.text = "%s — Press %s to roll!" % [pname, action_key]

func _proc_waiting(delta: float) -> void:
	if _player_order.is_empty():
		return
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
		_dice_cycle -= 0.07
		_dice_value  = _rng.randi_range(1, 6)
	if _dice_timer >= DICE_ANIM_DURATION:
		_dice_value     = _rng.randi_range(1, 6)
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
			_spawn_landing_particles(_hop_to_idx, stype)
			_effect_lbl.text    = _effect_msg
			_effect_lbl.visible = true
			_effect_bg.visible  = true
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
		_effect_bg.visible  = false
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
			_effect_msg = opts[_rng.randi() % opts.size()]
		SpaceType.LUCKY:
			dc = 2
			_effect_msg = "Florida Sunshine!  +2 Coins!"
		SpaceType.UNLUCKY:
			dc = -2
			_effect_msg = "Gator Attack!  -2 Coins!"
		SpaceType.BONUS:
			dc = _rng.randi_range(2, 4)
			_effect_msg = "Florida Man SCORES!  +%d Coins!" % dc
		SpaceType.PENALTY:
			dc = -_rng.randi_range(1, 3)
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
			# Arc the hop slightly upward for a bounce feel
			var t: float = _hop_progress
			var arc: float = sin(t * PI) * -14.0
			return pa.lerp(pb, t) + Vector2(0, arc)
	var idx: int        = GameSession.board_positions.get(player_id, 0)
	var sp:  Dictionary = _spaces[idx]
	return sp["pos"]

func _token_offset(player_id: int) -> Vector2:
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

	# Subtle dark green tint over 3D backdrop — not solid so 3D shows through
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.07, 0.02, 0.26))

	# Inner board area — semi-transparent so 3D landscape is visible at edges
	var itl: Vector2 = Vector2(MARGIN + SPACE_SZ + 4.0, MARGIN + SPACE_SZ + 4.0)
	var isz: Vector2 = vp - itl * 2.0
	draw_rect(Rect2(itl, isz), Color(0.04, 0.16, 0.04, 0.80))

	# Animated border glow on inner board
	var t_border: float = fmod(Time.get_ticks_msec() * 0.0014, TAU)
	draw_rect(Rect2(itl, isz), Color(0.22, 0.68, 0.18, 0.28 + 0.14 * sin(t_border)), false, 3.0)

	# Center labels
	draw_string(font, Vector2(cx, cy - 52.0), "FLORIDA MEN",
		HORIZONTAL_ALIGNMENT_CENTER, 280.0, 32, Color(0.52, 1.00, 0.28))
	draw_string(font, Vector2(cx, cy - 16.0),
		"Round %d / %d" % [GameSession.round_number + 1, GameSession.ROUNDS_PER_MATCH],
		HORIZONTAL_ALIGNMENT_CENTER, 280.0, 18, Color(0.78, 0.92, 0.65))
	_draw_legend(font, cx, cy)

	# Path connections (thicker, slightly glowing)
	for i: int in SPACE_COUNT:
		var sp_a: Dictionary = _spaces[i]
		var sp_b: Dictionary = _spaces[(i + 1) % SPACE_COUNT]
		var pa:   Vector2    = sp_a["pos"]
		var pb:   Vector2    = sp_b["pos"]
		var mid:  Vector2    = (pa + pb) * 0.5 + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5)
		draw_line(pa + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5),
		          pb + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5),
		          Color(0.38, 0.58, 0.35, 0.75), 4.0)

	# Active-player space pulse rings
	if not _player_order.is_empty() and \
			(_state == TurnState.WAITING_FOR_ROLL or _state == TurnState.ROLLING):
		var pid: int        = _player_order[_turn_idx]
		var idx: int        = GameSession.board_positions.get(pid, 0)
		var sp:  Dictionary = _spaces[idx]
		var pos: Vector2    = sp["pos"]
		var t:   float      = fmod(Time.get_ticks_msec() * 0.003, TAU)
		draw_rect(Rect2(pos - Vector2(4.0, 4.0), Vector2(SPACE_SZ + 8.0, SPACE_SZ + 8.0)),
			Color(1.0, 1.0, 0.22, 0.45 + 0.30 * sin(t)), false, 4.0)
		draw_rect(Rect2(pos - Vector2(9.0, 9.0), Vector2(SPACE_SZ + 18.0, SPACE_SZ + 18.0)),
			Color(1.0, 1.0, 0.22, 0.18 + 0.14 * sin(t + 1.0)), false, 2.5)

	# Spaces
	for i: int in SPACE_COUNT:
		var sp:    Dictionary = _spaces[i]
		var pos:   Vector2    = sp["pos"]
		var stype: int        = sp["type"]
		var col:   Color      = SPACE_COL[stype]
		var r:     Rect2      = Rect2(pos, Vector2(SPACE_SZ, SPACE_SZ))

		# Drop shadow
		draw_rect(Rect2(pos + Vector2(4.0, 4.0), Vector2(SPACE_SZ, SPACE_SZ)), Color(0.0, 0.0, 0.0, 0.50))
		# Main tile
		draw_rect(r, col)
		# Top/left highlight edges
		draw_line(pos, pos + Vector2(SPACE_SZ - 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.30), 1.5)
		draw_line(pos, pos + Vector2(0.0, SPACE_SZ - 1.0), Color(1.0, 1.0, 1.0, 0.22), 1.5)
		# Border
		draw_rect(r, col.darkened(0.35), false, 2.0)
		# Icon
		draw_string(font, Vector2(pos.x, pos.y + SPACE_SZ * 0.60 + 5.0),
			SPACE_ICON[stype], HORIZONTAL_ALIGNMENT_CENTER, SPACE_SZ, 20, Color.WHITE)
		# Number
		draw_string(font, Vector2(pos.x + 3.0, pos.y + 12.0),
			str(i), HORIZONTAL_ALIGNMENT_LEFT, SPACE_SZ, 10, Color(1.0, 1.0, 1.0, 0.60))

		# Animated glow for special spaces
		if stype == SpaceType.LUCKY or stype == SpaceType.BONUS or stype == SpaceType.START:
			var t: float = fmod(Time.get_ticks_msec() * 0.0030, TAU)
			draw_rect(Rect2(pos - Vector2(2.5, 2.5), Vector2(SPACE_SZ + 5.0, SPACE_SZ + 5.0)),
					Color(1.0, 0.92, 0.20, 0.20 + 0.15 * sin(t)), false, 3.0)
		elif stype == SpaceType.UNLUCKY or stype == SpaceType.PENALTY:
			var t: float = fmod(Time.get_ticks_msec() * 0.0038, TAU)
			draw_rect(Rect2(pos - Vector2(2.5, 2.5), Vector2(SPACE_SZ + 5.0, SPACE_SZ + 5.0)),
					Color(1.0, 0.15, 0.10, 0.16 + 0.12 * sin(t)), false, 3.0)

	# Player tokens
	for p: Dictionary in GameSession.players:
		var pid:    int     = p.id
		var vpos:   Vector2 = _get_token_visual_pos(pid)
		var pcol:   Color   = PLAYER_COL[mini(pid, PLAYER_COL.size() - 1)]
		var offset: Vector2 = _token_offset(pid)
		var center: Vector2 = vpos + Vector2(SPACE_SZ * 0.5, SPACE_SZ * 0.5) + offset

		# Shadow
		draw_circle(center + Vector2(3.0, 3.0), 15.0, Color(0.0, 0.0, 0.0, 0.46))
		# Outer rim
		draw_circle(center, 15.0, pcol.darkened(0.28))
		# Body
		draw_circle(center, 12.0, pcol)
		# Shine
		draw_circle(center + Vector2(-4.0, -4.0), 4.5, Color(1.0, 1.0, 1.0, 0.30))
		# Ring
		draw_arc(center, 12.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.58), 1.5)
		# Player number
		draw_string(font, Vector2(center.x, center.y + 5.0),
			str(pid + 1), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 14, Color.WHITE)

		# Active player pulse rings
		if (_state == TurnState.WAITING_FOR_ROLL or _state == TurnState.ROLLING) \
				and pid == _player_order[_turn_idx]:
			var t: float = fmod(Time.get_ticks_msec() * 0.005, TAU)
			draw_arc(center, 18.5, 0.0, TAU, 32, Color(1.0, 0.92, 0.18, 0.68 + 0.28 * sin(t)), 2.5)
			draw_arc(center, 22.5, 0.0, TAU, 32, Color(1.0, 0.92, 0.18, 0.28 + 0.18 * sin(t + 1.1)), 1.5)

	_draw_dice(vp, font)

func _draw_legend(font: Font, cx: float, cy: float) -> void:
	var types: Array  = [SpaceType.LUCKY, SpaceType.UNLUCKY, SpaceType.BONUS, SpaceType.PENALTY, SpaceType.START]
	var labels: Array = ["Lucky +$", "Unlucky -$", "Bonus +$$", "Penalty -$", "GO +3"]
	var leg_y: float  = cy + 28.0
	var leg_x: float  = cx - (types.size() - 1) * 40.0
	for i: int in types.size():
		var col: Color = SPACE_COL[types[i]]
		draw_rect(Rect2(Vector2(leg_x + i * 80.0 - 10.0, leg_y - 10.0), Vector2(20.0, 20.0)), col)
		draw_rect(Rect2(Vector2(leg_x + i * 80.0 - 11.0, leg_y - 11.0), Vector2(22.0, 22.0)),
				col.darkened(0.35), false, 1.5)
		draw_string(font, Vector2(leg_x + i * 80.0, leg_y + 16.0),
			labels[i], HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11, Color(0.82, 0.92, 0.72))

func _draw_dice(vp: Vector2, font: Font) -> void:
	if not _dice_rolled or _state == TurnState.WAITING_FOR_ROLL:
		return

	var dsize: float   = 90.0
	var dcx:   float   = vp.x * 0.5
	var dcy:   float   = vp.y * 0.33
	var dtl:   Vector2 = Vector2(dcx - dsize * 0.5, dcy - dsize * 0.5)
	var dr:    Rect2   = Rect2(dtl, Vector2(dsize, dsize))

	# Rolling glow burst
	if _state == TurnState.ROLLING:
		var t: float = fmod(Time.get_ticks_msec() * 0.010, TAU)
		var g: float = 10.0 + 5.0 * sin(t)
		draw_rect(Rect2(dtl - Vector2(g, g), Vector2(dsize + g * 2.0, dsize + g * 2.0)),
			Color(1.0, 0.85, 0.10, 0.38 + 0.26 * sin(t)))

	# 3D-look die: shadow + side panels + face
	draw_rect(Rect2(dtl + Vector2(6.0, 6.0), Vector2(dsize, dsize)), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(Rect2(dtl + Vector2(dsize, 4.0), Vector2(6.0, dsize)), Color(0.50, 0.50, 0.48))
	draw_rect(Rect2(dtl + Vector2(4.0, dsize), Vector2(dsize + 2.0, 6.0)), Color(0.46, 0.46, 0.44))
	draw_rect(dr, Color(0.97, 0.97, 0.95))
	# Face highlights
	draw_line(dtl, dtl + Vector2(dsize, 0.0), Color(1.0, 1.0, 1.0, 0.75), 2.0)
	draw_line(dtl, dtl + Vector2(0.0, dsize), Color(1.0, 1.0, 1.0, 0.55), 2.0)
	# Border
	draw_rect(dr, Color(0.18, 0.18, 0.18), false, 2.0)

	# Pips with drop shadow
	var pips: Array[Vector2] = _pip_positions(_dice_value, Vector2(dcx, dcy), dsize * 0.27)
	for pip: Vector2 in pips:
		draw_circle(pip + Vector2(1.0, 1.0), 6.5, Color(0.0, 0.0, 0.0, 0.28))
		draw_circle(pip, 6.5, Color(0.08, 0.08, 0.08))

	draw_string(font, Vector2(dcx, dcy + dsize * 0.5 + 22.0),
		"Rolled: %d" % _dice_value, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 15,
		Color(0.92, 0.90, 0.70))
