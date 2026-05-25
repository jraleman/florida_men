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

# 3D board tile layout — rectangular ring matching the 2D path proportions
const TILE_XS: float   = 1.65    # x-step between tile centers (top/bottom rows)
const TILE_ZS: float   = 1.60    # z-step between tile centers (side columns)
const TILE_X0: float   = -5.775  # x center of tile 0 (top-left corner)
const TILE_Z0: float   = -4.0    # z center of the top row
const TILE_CY: float   = 0.20    # tile mesh center Y (sits above inner terrain)
const TILE_SZ: Vector3 = Vector3(1.40, 0.30, 1.40)

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
var _coins_lbl:  Label

var _board_root: Node3D = null
var _cam_node: Camera3D = null
var _cam_orbit_angle: float = 0.0
var _space_positions_3d: Array = []    # Vector3 per space
var _space_mats: Array = []            # StandardMaterial3D per space (for pulse)
var _token_nodes: Array = []           # Node3D per player slot
var _center_sign: Node3D = null
var _sign_panel: Node3D = null    # rotated via look_at each frame (mesh only)
var _round_lbl_3d: Label3D = null

var _effect_popup_root: Node3D = null
var _popup_panel_node: Node3D = null
var _popup_border_mat: StandardMaterial3D = null
var _popup_backing_mat: StandardMaterial3D = null
var _effect_popup_lbl: Label3D = null

# ── Ready ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_setup_3d_scene()
	_build_3d_center_sign()
	_init_space_positions_3d()
	_build_3d_tiles()
	_setup_landing_particles()
	_build_spaces()
	_build_hud()
	_player_order.clear()
	for p: Dictionary in GameSession.players:
		_player_order.append(p.id)
	_build_player_tokens_3d()
	_begin_turn()

# ── 3D backdrop ───────────────────────────────────────────────────────────────

func _setup_3d_scene() -> void:
	# Orbiting camera — added to tree first, then oriented (look_at needs tree)
	_cam_node = Camera3D.new()
	_cam_node.position = Vector3(0, 6.5, 9.0)
	sub_viewport.add_child(_cam_node)
	_cam_node.look_at(Vector3(0, 0.5, 0))

	# Matching scoreboard sky color
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.38, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.85, 1.0)
	env.ambient_light_energy = 3.0
	world_env.environment = env
	sub_viewport.add_child(world_env)

	# Directional sun
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 22, 0)
	sun.light_color = Color(1.0, 0.92, 0.65)
	sun.light_energy = 3.5
	sun.shadow_enabled = false
	sub_viewport.add_child(sun)

	# Fill light from blue sky side
	var fill := OmniLight3D.new()
	fill.position = Vector3(-5, 6, 0)
	fill.light_color = Color(0.40, 0.65, 1.0)
	fill.light_energy = 2.0
	fill.omni_range = 22.0
	sub_viewport.add_child(fill)

	# Glowing sun sphere in the sky
	var sun_mi := MeshInstance3D.new()
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 0.9
	sun_mesh.height = 1.8
	sun_mi.mesh = sun_mesh
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color(1.0, 0.95, 0.40)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.88, 0.20)
	sun_mat.emission_energy_multiplier = 9.0
	sun_mi.material_override = sun_mat
	sun_mi.position = Vector3(9, 10, -7)
	sub_viewport.add_child(sun_mi)

	var sun_halo := OmniLight3D.new()
	sun_halo.position = Vector3(9, 10, -7)
	sun_halo.light_color = Color(1.0, 0.88, 0.40)
	sun_halo.light_energy = 3.5
	sun_halo.omni_range = 28.0
	sub_viewport.add_child(sun_halo)

	_board_root = Node3D.new()
	sub_viewport.add_child(_board_root)

	# Ocean surrounding the island
	_make_3d_box(_board_root, Vector3(0, -1.2, 0), Vector3(28, 0.8, 18),
			Color(0.14, 0.52, 0.88), 0.12, 0.50)
	# Florida island (green landmass)
	_make_3d_box(_board_root, Vector3(0, -0.6, 0), Vector3(19, 0.8, 12),
			Color(0.20, 0.62, 0.20), 0.05, 0.80)
	# Inner terrain — enlarged to accommodate all 24 3D tiles
	_make_3d_box(_board_root, Vector3(0, -0.2, 0), Vector3(15.0, 0.5, 10.5),
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

# ── 3D center sign ────────────────────────────────────────────────────────────

func _build_3d_center_sign() -> void:
	_center_sign = Node3D.new()
	_center_sign.position = Vector3(0, 4.5, 0)
	sub_viewport.add_child(_center_sign)

	# _sign_panel holds the box meshes and is look_at-rotated each frame.
	# Boxes are symmetric so mirroring from look_at doesn't affect appearance.
	_sign_panel = Node3D.new()
	_center_sign.add_child(_sign_panel)

	# Gold border frame — slightly larger, behind the main panel
	var border_mi := MeshInstance3D.new()
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(5.5, 2.05, 0.12)
	border_mi.mesh = border_mesh
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.90, 0.70, 0.05)
	border_mat.emission_enabled = true
	border_mat.emission = Color(1.0, 0.85, 0.10)
	border_mat.emission_energy_multiplier = 4.5
	border_mi.material_override = border_mat
	border_mi.position = Vector3(0, 0, 0.04)
	_sign_panel.add_child(border_mi)

	# Dark navy backing panel
	var panel_mi := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(5.15, 1.78, 0.16)
	panel_mi.mesh = panel_mesh
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.02, 0.05, 0.20)
	panel_mat.emission_enabled = true
	panel_mat.emission = Color(0.04, 0.10, 0.42)
	panel_mat.emission_energy_multiplier = 1.8
	panel_mi.material_override = panel_mat
	_sign_panel.add_child(panel_mi)

	# Labels use BILLBOARD_FIXED_Y — Godot's billboard path uses the camera's
	# actual right vector so text reads left-to-right regardless of orbit angle.
	# They are direct children of _center_sign (not _sign_panel) so they
	# billboard independently of the panel's look_at rotation.
	var title_lbl := Label3D.new()
	title_lbl.text = "FLORIDA MEN"
	title_lbl.position = Vector3(0, 0.45, 0)
	title_lbl.pixel_size = 0.006
	title_lbl.font_size = 72
	title_lbl.modulate = Color(1.0, 0.88, 0.12)
	title_lbl.no_depth_test = true
	title_lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_center_sign.add_child(title_lbl)

	_round_lbl_3d = Label3D.new()
	_round_lbl_3d.text = "Round 1 / %d" % GameSession.rounds_per_match
	_round_lbl_3d.position = Vector3(0, -0.30, 0)
	_round_lbl_3d.pixel_size = 0.006
	_round_lbl_3d.font_size = 40
	_round_lbl_3d.modulate = Color(0.88, 0.95, 1.00)
	_round_lbl_3d.no_depth_test = true
	_round_lbl_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_center_sign.add_child(_round_lbl_3d)

	# Warm glow light — illuminates nearby tiles
	var sign_light := OmniLight3D.new()
	sign_light.light_color = Color(1.0, 0.82, 0.20)
	sign_light.light_energy = 2.5
	sign_light.omni_range = 5.5
	_center_sign.add_child(sign_light)

# ── 3D effect popup ───────────────────────────────────────────────────────────

func _spawn_effect_popup(space_idx: int, space_type: int) -> void:
	_dismiss_effect_popup()
	var col: Color = SPACE_COL[space_type]

	_effect_popup_root = Node3D.new()
	_effect_popup_root.position = _space_positions_3d[space_idx] + Vector3(0, 1.8, 0)
	_effect_popup_root.scale = Vector3.ZERO
	sub_viewport.add_child(_effect_popup_root)

	# Panel node — rotated via look_at each frame (symmetric boxes, no mirroring issue)
	_popup_panel_node = Node3D.new()
	_effect_popup_root.add_child(_popup_panel_node)

	var border_mi := MeshInstance3D.new()
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(3.2, 1.0, 0.10)
	border_mi.mesh = border_mesh
	_popup_border_mat = StandardMaterial3D.new()
	_popup_border_mat.albedo_color = col
	_popup_border_mat.emission_enabled = true
	_popup_border_mat.emission = col
	_popup_border_mat.emission_energy_multiplier = 3.5
	_popup_border_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	border_mi.material_override = _popup_border_mat
	border_mi.position = Vector3(0, 0, 0.02)
	_popup_panel_node.add_child(border_mi)

	var backing_mi := MeshInstance3D.new()
	var backing_mesh := BoxMesh.new()
	backing_mesh.size = Vector3(3.0, 0.82, 0.12)
	backing_mi.mesh = backing_mesh
	_popup_backing_mat = StandardMaterial3D.new()
	_popup_backing_mat.albedo_color = Color(0.02, 0.05, 0.20)
	_popup_backing_mat.emission_enabled = true
	_popup_backing_mat.emission = Color(0.04, 0.10, 0.42)
	_popup_backing_mat.emission_energy_multiplier = 1.5
	_popup_backing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	backing_mi.material_override = _popup_backing_mat
	_popup_panel_node.add_child(backing_mi)

	# Label uses BILLBOARD_FIXED_Y — text never mirrors regardless of camera angle
	_effect_popup_lbl = Label3D.new()
	_effect_popup_lbl.text = _effect_msg
	_effect_popup_lbl.pixel_size = 0.005
	_effect_popup_lbl.font_size = 52
	_effect_popup_lbl.modulate = Color(1.0, 0.95, 0.55)
	_effect_popup_lbl.no_depth_test = true
	_effect_popup_lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_effect_popup_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_popup_lbl.width = 500
	_effect_popup_root.add_child(_effect_popup_lbl)

func _dismiss_effect_popup() -> void:
	if _effect_popup_root != null:
		_effect_popup_root.queue_free()
		_effect_popup_root = null
		_popup_panel_node  = null
		_popup_border_mat  = null
		_popup_backing_mat = null
		_effect_popup_lbl  = null

# ── 3D board tiles & player tokens ────────────────────────────────────────────

func _init_space_positions_3d() -> void:
	_space_positions_3d.clear()
	for i: int in 8:
		_space_positions_3d.append(Vector3(TILE_X0 + float(i) * TILE_XS, TILE_CY, TILE_Z0))
	for i: int in 4:
		_space_positions_3d.append(Vector3(TILE_X0 + 7.0 * TILE_XS, TILE_CY, TILE_Z0 + float(i + 1) * TILE_ZS))
	for i: int in 8:
		_space_positions_3d.append(Vector3(TILE_X0 + float(7 - i) * TILE_XS, TILE_CY, TILE_Z0 + 5.0 * TILE_ZS))
	for i: int in 4:
		_space_positions_3d.append(Vector3(TILE_X0, TILE_CY, TILE_Z0 + float(4 - i) * TILE_ZS))

func _build_3d_tiles() -> void:
	_space_mats.clear()
	for i: int in SPACE_COUNT:
		var pos3d: Vector3 = _space_positions_3d[i]
		var stype: int = SPACE_TYPE_LIST[i]
		var col: Color = SPACE_COL[stype]

		var tile_root := Node3D.new()
		tile_root.position = pos3d
		_board_root.add_child(tile_root)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = TILE_SZ
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.5
		mat.roughness = 0.55
		mi.material_override = mat
		tile_root.add_child(mi)
		_space_mats.append(mat)

		var lbl := Label3D.new()
		lbl.text = SPACE_ICON[stype]
		lbl.position = Vector3(0, TILE_SZ.y * 0.5 + 0.01, 0)
		lbl.rotation_degrees = Vector3(-90, 0, 0)
		lbl.pixel_size = 0.007
		lbl.font_size = 36
		lbl.modulate = Color(1.0, 1.0, 1.0, 0.88)
		lbl.no_depth_test = true
		tile_root.add_child(lbl)

func _build_player_tokens_3d() -> void:
	_token_nodes.clear()
	for i: int in GameSession.players.size():
		var p: Dictionary = GameSession.players[i]
		var pid: int = p.id
		var col: Color = PLAYER_COL[mini(pid, PLAYER_COL.size() - 1)]

		var root := Node3D.new()
		_board_root.add_child(root)

		var base_mi := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.height = 0.08
		base_mesh.top_radius = 0.32
		base_mesh.bottom_radius = 0.36
		base_mi.mesh = base_mesh
		var base_mat := StandardMaterial3D.new()
		base_mat.albedo_color = col.darkened(0.25)
		base_mat.emission_enabled = true
		base_mat.emission = col.darkened(0.25)
		base_mat.emission_energy_multiplier = 1.2
		base_mi.material_override = base_mat
		base_mi.position = Vector3(0, 0.04, 0)
		root.add_child(base_mi)

		var body_mi := MeshInstance3D.new()
		var body_mesh := CylinderMesh.new()
		body_mesh.height = 0.55
		body_mesh.top_radius = 0.13
		body_mesh.bottom_radius = 0.20
		body_mi.mesh = body_mesh
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = col
		body_mat.emission_enabled = true
		body_mat.emission = col
		body_mat.emission_energy_multiplier = 1.8
		body_mi.material_override = body_mat
		body_mi.position = Vector3(0, 0.36, 0)
		root.add_child(body_mi)

		var head_mi := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.20
		head_mesh.height = 0.40
		head_mi.mesh = head_mesh
		var head_mat := StandardMaterial3D.new()
		head_mat.albedo_color = col.lightened(0.15)
		head_mat.emission_enabled = true
		head_mat.emission = col.lightened(0.15)
		head_mat.emission_energy_multiplier = 2.0
		head_mi.material_override = head_mat
		head_mi.position = Vector3(0, 0.76, 0)
		root.add_child(head_mi)

		var num_lbl := Label3D.new()
		num_lbl.text = str(pid + 1)
		num_lbl.position = Vector3(0, 1.10, 0)
		num_lbl.pixel_size = 0.006
		num_lbl.font_size = 42
		num_lbl.modulate = Color.WHITE
		num_lbl.no_depth_test = true
		num_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(num_lbl)

		_token_nodes.append(root)

func _get_token_visual_pos_3d(player_id: int) -> Vector3:
	var on_tile := Vector3(0, TILE_SZ.y * 0.5, 0)
	if _state == TurnState.MOVING and not _player_order.is_empty():
		var mover: int = _player_order[_turn_idx]
		if mover == player_id:
			var pa: Vector3 = _space_positions_3d[_hop_from_idx] + on_tile
			var pb: Vector3 = _space_positions_3d[_hop_to_idx] + on_tile
			var t: float = _hop_progress
			var pos: Vector3 = pa.lerp(pb, t)
			pos.y += sin(t * PI) * 1.2
			return pos
	var idx: int = GameSession.board_positions.get(player_id, 0)
	if idx < _space_positions_3d.size():
		return _space_positions_3d[idx] + on_tile
	return Vector3.ZERO

func _token_offset_3d(player_id: int) -> Vector3:
	var pid_pos: int = GameSession.board_positions.get(player_id, 0)
	var same: Array = []
	for op in _player_order:
		var other: int = op
		if GameSession.board_positions.get(other, 0) == pid_pos:
			same.append(other)
	if same.size() <= 1:
		return Vector3.ZERO
	var offs: Array[Vector3] = [
		Vector3(-0.35, 0.0, -0.35), Vector3(0.35, 0.0, -0.35),
		Vector3(-0.35, 0.0,  0.35), Vector3(0.35, 0.0,  0.35),
	]
	var i: int = same.find(player_id)
	if i < 0 or i >= offs.size():
		return Vector3.ZERO
	return offs[i]

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
	status_bg.color = Color(0.02, 0.06, 0.12, 0.82)
	_hud.add_child(status_bg)

	_status_lbl = Label.new()
	_status_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	_status_lbl.set_anchor_and_offset(SIDE_RIGHT,  1.0,  0.0)
	_status_lbl.set_anchor_and_offset(SIDE_TOP,    0.0,  6.0)
	_status_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 42.0)
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 20)
	_status_lbl.add_theme_color_override("font_color", Color(0.90, 0.96, 1.00, 1))
	_hud.add_child(_status_lbl)

	var coins_bg := ColorRect.new()
	coins_bg.set_anchor_and_offset(SIDE_LEFT,   0.0,  0.0)
	coins_bg.set_anchor_and_offset(SIDE_RIGHT,  0.20, 0.0)
	coins_bg.set_anchor_and_offset(SIDE_TOP,    0.0, 44.0)
	coins_bg.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	coins_bg.color = Color(0.02, 0.06, 0.12, 0.82)
	_hud.add_child(coins_bg)

	_coins_lbl = Label.new()
	_coins_lbl.set_anchor_and_offset(SIDE_LEFT,   0.0,  8.0)
	_coins_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.20, 0.0)
	_coins_lbl.set_anchor_and_offset(SIDE_TOP,    0.0, 52.0)
	_coins_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1.0,  0.0)
	_coins_lbl.add_theme_font_size_override("font_size", 15)
	_coins_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 1.00, 1))
	_hud.add_child(_coins_lbl)
	_refresh_coins_lbl()

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _cam_node != null:
		_cam_orbit_angle += 4.5 * delta
		var rad: float = deg_to_rad(_cam_orbit_angle)
		_cam_node.position = Vector3(sin(rad) * 9.0, 6.5, cos(rad) * 9.0)
		_cam_node.look_at(Vector3(0, 0.5, 0))

	# Animate 3D center sign — gentle bob; panel tracks camera, labels billboard
	if _center_sign != null and _cam_node != null:
		var t_sign: float = Time.get_ticks_msec() * 0.001
		_center_sign.position.y = 4.5 + sin(t_sign * 1.2) * 0.10
		if _sign_panel != null:
			var look_pos: Vector3 = _cam_node.global_position
			look_pos.y = _sign_panel.global_position.y
			_sign_panel.look_at(look_pos, Vector3.UP)

	if _round_lbl_3d != null:
		_round_lbl_3d.text = "Round %d / %d" % [GameSession.round_number + 1, GameSession.rounds_per_match]

	# Pulse the active/destination tile
	if _space_mats.size() == SPACE_COUNT and not _player_order.is_empty():
		for i: int in SPACE_COUNT:
			var m: StandardMaterial3D = _space_mats[i]
			m.emission_energy_multiplier = 1.5
		var hl: int = -1
		if _state == TurnState.WAITING_FOR_ROLL or _state == TurnState.ROLLING:
			var pid: int = _player_order[_turn_idx]
			hl = GameSession.board_positions.get(pid, 0)
		elif _state == TurnState.MOVING:
			hl = _hop_to_idx
		if hl >= 0:
			var m: StandardMaterial3D = _space_mats[hl]
			var tp: float = fmod(Time.get_ticks_msec() * 0.003, TAU)
			m.emission_energy_multiplier = 3.5 + 2.0 * sin(tp)

	# Update 3D player token positions
	var n: int = mini(_token_nodes.size(), GameSession.players.size())
	for i: int in n:
		var p: Dictionary = GameSession.players[i]
		var pid: int = p.id
		var token: Node3D = _token_nodes[i]
		token.position = _get_token_visual_pos_3d(pid) + _token_offset_3d(pid)

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
	_dismiss_effect_popup()
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
			_spawn_effect_popup(_hop_to_idx, stype)
			_status_lbl.text    = ""
			_effect_timer       = 0.0
			_state              = TurnState.SPACE_EFFECT
		else:
			_hop_from_idx = _hop_to_idx
			_hop_to_idx   = (_hop_to_idx + 1) % SPACE_COUNT

func _proc_effect(delta: float) -> void:
	_effect_timer += delta

	if _effect_popup_root != null and _cam_node != null:
		# Rise upward continuously
		_effect_popup_root.position.y += 0.55 * delta

		# Scale pop-in: 0→1.15 over first 75% of 0.35s, then 1.15→1.0 for rest
		var scale_t: float = minf(_effect_timer / 0.35, 1.0)
		var s: float
		if scale_t < 0.75:
			s = (scale_t / 0.75) * 1.15
		else:
			s = 1.15 - ((scale_t - 0.75) / 0.25) * 0.15
		_effect_popup_root.scale = Vector3(s, s, s)

		# Panel faces camera — guard until scale is non-degenerate (avoids det==0)
		if _popup_panel_node != null and s > 0.05:
			var look_pos: Vector3 = _cam_node.global_position
			look_pos.y = _popup_panel_node.global_position.y
			_popup_panel_node.look_at(look_pos, Vector3.UP)

		# Fade out over second half of effect
		var fade_start: float = EFFECT_DURATION * 0.5
		var alpha: float = 1.0 - clampf((_effect_timer - fade_start) / (EFFECT_DURATION * 0.5), 0.0, 1.0)
		if _effect_popup_lbl != null:
			_effect_popup_lbl.modulate.a = alpha
		if _popup_border_mat != null:
			var bc: Color = _popup_border_mat.albedo_color
			_popup_border_mat.albedo_color = Color(bc.r, bc.g, bc.b, alpha)
			_popup_border_mat.emission_energy_multiplier = 3.5 * alpha
		if _popup_backing_mat != null:
			var pbc: Color = _popup_backing_mat.albedo_color
			_popup_backing_mat.albedo_color = Color(pbc.r, pbc.g, pbc.b, alpha)

	if _effect_timer >= EFFECT_DURATION:
		_dismiss_effect_popup()
		_trans_timer = 0.0
		_state       = TurnState.TRANSITION

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

	# Minimal tint — 3D scene carries all the visual weight now
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.04, 0.08, 0.10))

	# Bottom legend strip with a dark panel + blue top border line
	draw_rect(Rect2(Vector2(0, vp.y - 66.0), Vector2(vp.x, 66.0)),
		Color(0.01, 0.04, 0.12, 0.68))
	draw_line(Vector2(0, vp.y - 66.0), Vector2(vp.x, vp.y - 66.0),
		Color(0.30, 0.60, 1.00, 0.45), 1.5)
	_draw_legend(font, cx, vp.y - 40.0)

	_draw_dice(vp, font)

func _draw_legend(font: Font, cx: float, leg_y: float) -> void:
	var types: Array  = [SpaceType.LUCKY, SpaceType.UNLUCKY, SpaceType.BONUS, SpaceType.PENALTY, SpaceType.START]
	var labels: Array = ["Lucky +$", "Unlucky -$", "Bonus +$$", "Penalty -$", "GO +3"]
	var leg_x: float  = cx - (types.size() - 1) * 40.0
	for i: int in types.size():
		var col: Color = SPACE_COL[types[i]]
		draw_rect(Rect2(Vector2(leg_x + i * 80.0 - 10.0, leg_y - 10.0), Vector2(20.0, 20.0)), col)
		draw_rect(Rect2(Vector2(leg_x + i * 80.0 - 11.0, leg_y - 11.0), Vector2(22.0, 22.0)),
				col.darkened(0.35), false, 1.5)
		draw_string(font, Vector2(leg_x + i * 80.0, leg_y + 16.0),
			labels[i], HORIZONTAL_ALIGNMENT_CENTER, 80.0, 11, Color(0.88, 0.95, 1.00))

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
