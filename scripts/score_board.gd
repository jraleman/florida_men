extends Control

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var confetti_left: CPUParticles2D = $ConfettiLeft
@onready var confetti_right: CPUParticles2D = $ConfettiRight
@onready var flash_rect: ColorRect = $FlashRect
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var round_winner_label: Label = $VBoxContainer/RoundWinnerLabel
@onready var scores_container: VBoxContainer = $VBoxContainer/ScoresPanel/ScoresContainer
@onready var history_panel: PanelContainer = $VBoxContainer/HistoryPanel
@onready var history_container: VBoxContainer = $VBoxContainer/HistoryPanel/HistoryInner/HistoryContainer
@onready var rematch_button: Button = $VBoxContainer/ButtonRow/RematchButton
@onready var continue_button: Button = $VBoxContainer/ButtonRow/ContinueButton

const PLACEMENT_LABELS := ["1st", "2nd", "3rd", "4th"]

const RANK_LOCATIONS: PackedStringArray = [
	"☀️ Miami Beach",
	"🌊 Tampa Bay",
	"🐊 The Everglades",
	"🚀 Cape Canaveral",
]

const RANK_BG_COLORS: Array[Color] = [
	Color(0.72, 0.44, 0.05, 1),
	Color(0.10, 0.38, 0.70, 1),
	Color(0.16, 0.44, 0.12, 1),
	Color(0.28, 0.14, 0.05, 1),
]

var _podium_root: Node3D = null
var _match_over := false

func _ready() -> void:
	rematch_button.pressed.connect(_on_rematch_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	MusicManager.play_music("scoreboard")
	_setup_3d_scene()
	_setup_confetti_particles()
	_display_scores()
	call_deferred("_start_effects")

func _process(delta: float) -> void:
	if _podium_root != null:
		_podium_root.rotation_degrees.y += 20.0 * delta

# ── 3D backdrop ──────────────────────────────────────────────────────────────

func _setup_3d_scene() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.5, 8.5)
	cam.rotation_degrees = Vector3(-14, 0, 0)
	sub_viewport.add_child(cam)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.38, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.90, 0.78, 0.55)
	env.ambient_light_energy = 3.0
	world_env.environment = env
	sub_viewport.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 28, 0)
	sun.light_color = Color(1.0, 0.90, 0.60)
	sun.light_energy = 3.5
	sun.shadow_enabled = false
	sub_viewport.add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-4, 3, 5)
	fill.light_color = Color(0.45, 0.65, 1.0)
	fill.light_energy = 2.5
	fill.omni_range = 18.0
	sub_viewport.add_child(fill)

	_podium_root = Node3D.new()
	sub_viewport.add_child(_podium_root)

	# Ocean floor
	_make_box(_podium_root, Vector3(0, -2.1, 0), Vector3(20, 1.4, 10),
			Color(0.16, 0.58, 0.88), 0.08, 0.55)

	# Gold 1st – center, tallest
	_make_podium(_podium_root, Vector3(0, -1.4, 0), 2.8, Color(1.00, 0.80, 0.14))
	# Silver 2nd – left
	_make_podium(_podium_root, Vector3(-2.3, -1.4, 0), 2.0, Color(0.76, 0.76, 0.82))
	# Bronze 3rd – right
	_make_podium(_podium_root, Vector3(2.3, -1.4, 0), 1.5, Color(0.72, 0.46, 0.22))

	# Floating star above gold podium
	_make_box(_podium_root, Vector3(0, 2.2, 0), Vector3(0.45, 0.45, 0.45),
			Color(1.0, 0.92, 0.20), 0.8, 0.05)

func _make_box(parent: Node3D, pos: Vector3, sz: Vector3, color: Color,
		metallic: float, roughness: float) -> MeshInstance3D:
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
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _make_podium(parent: Node3D, base: Vector3, height: float, color: Color) -> void:
	var w := 1.55
	var d := 1.55
	_make_box(parent, base + Vector3(0, height * 0.5, 0), Vector3(w, height, d), color, 0.55, 0.18)
	# Bright cap on top
	_make_box(parent, base + Vector3(0, height + 0.08, 0), Vector3(w * 0.94, 0.14, d * 0.94),
			color.lightened(0.28), 0.75, 0.08)

# ── Confetti ─────────────────────────────────────────────────────────────────

func _setup_confetti_particles() -> void:
	_configure_confetti(confetti_left, true)
	_configure_confetti(confetti_right, false)

func _configure_confetti(p: CPUParticles2D, from_left: bool) -> void:
	p.amount = 180
	p.lifetime = 5.5
	p.one_shot = true
	p.explosiveness = 0.65
	p.emitting = false
	p.gravity = Vector2(0, 230)
	p.initial_velocity_min = 270.0
	p.initial_velocity_max = 520.0
	p.direction = Vector2(1.0 if from_left else -1.0, -0.85)
	p.spread = 40.0
	p.angular_velocity_min = -210.0
	p.angular_velocity_max = 210.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 16.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(8, 160)
	p.color_ramp = _rainbow_gradient()

func _rainbow_gradient() -> Gradient:
	var g := Gradient.new()
	g.colors = PackedColorArray([
		Color(1, 0.18, 0.18, 1), Color(1, 0.58, 0.08, 1), Color(1, 1, 0.10, 1),
		Color(0.18, 1, 0.25, 1), Color(0.10, 0.50, 1, 1), Color(0.72, 0.10, 1, 1),
		Color(1, 0.18, 0.68, 1), Color(1, 1, 1, 0),
	])
	g.offsets = PackedFloat32Array([0.0, 0.14, 0.28, 0.42, 0.57, 0.71, 0.85, 1.0])
	return g

# ── Score display ─────────────────────────────────────────────────────────────

func _display_scores() -> void:
	_match_over = GameSession.is_match_over()

	if _match_over:
		title_label.text = "🏆 MATCH OVER! 🏆"
		round_winner_label.text = "Last round won by %s" % GameSession.get_last_round_winner_name()
		continue_button.text = "Back to Menu"
		rematch_button.visible = true
	else:
		title_label.text = "🌴 Round %d Results 🌴" % GameSession.round_number
		var winner := GameSession.get_last_round_winner_name()
		round_winner_label.text = "🌊 %s wins this round!" % winner if winner else ""
		continue_button.text = "Next Round"
		rematch_button.visible = false

	_populate_scores(_match_over)
	_populate_history(_match_over)

func _populate_scores(match_over: bool) -> void:
	for child in scores_container.get_children():
		child.queue_free()

	var sorted := GameSession.get_sorted_scores()
	var prev_score := -1
	var display_rank := 0
	for i in sorted.size():
		var entry: Dictionary = sorted[i]
		if entry.score != prev_score:
			display_rank = i
		prev_score = entry.score

		var coins_earned: int = GameSession.last_round_coins.get(entry.id, 0)
		var placement: String = PLACEMENT_LABELS[mini(display_rank, PLACEMENT_LABELS.size() - 1)]
		var tied: bool = i > 0 and sorted[i - 1].coins == entry.coins
		var tie_tag := " (tied)" if tied else ""
		var winner_tag := "  ★ MATCH WINNER" if (display_rank == 0 and match_over) else ""
		var rank_idx: int = mini(display_rank, RANK_BG_COLORS.size() - 1)
		var location: String = RANK_LOCATIONS[rank_idx]
		var card_color: Color = RANK_BG_COLORS[rank_idx]

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = card_color
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_right = 10
		style.corner_radius_bottom_left = 10
		style.content_margin_left = 16.0
		style.content_margin_top = 10.0
		style.content_margin_right = 16.0
		style.content_margin_bottom = 10.0

		if display_rank == 0:
			style.border_width_left = 5
			style.border_width_top = 5
			style.border_width_right = 5
			style.border_width_bottom = 5
			style.border_color = Color(1.0, 0.85, 0.20, 1)
		else:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.06, 0.03, 0.01, 1)

		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)

		var loc_label := Label.new()
		loc_label.text = location
		loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loc_label.add_theme_font_size_override("font_size", 12)
		loc_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 0.85))

		var main_label := Label.new()
		if match_over:
			main_label.text = "%s  %s%s  —  %d coins  (%d wins)%s" % [
				placement, entry.name, tie_tag, entry.coins, entry.wins, winner_tag
			]
		else:
			main_label.text = "%s  %s  +%d coins  (total: %d)" % [
				placement, entry.name, coins_earned, entry.coins
			]
		main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		main_label.add_theme_font_size_override("font_size", 26 if display_rank == 0 else 19)

		vbox.add_child(loc_label)
		vbox.add_child(main_label)
		panel.add_child(vbox)
		scores_container.add_child(panel)

		if display_rank == 0:
			_apply_winner_shimmer(panel)

func _apply_winner_shimmer(panel: PanelContainer) -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	float w = sin(UV.x * 9.0 + TIME * 3.5) * sin(UV.y * 5.0 - TIME * 1.8);
	float shimmer = w * 0.12 + 0.92;
	COLOR.rgb *= shimmer;
	float s = sin(UV.x * 41.0 + TIME * 5.2) * sin(UV.y * 31.0 + TIME * 3.1);
	COLOR.rgb += step(0.972, s) * vec3(1.0, 0.95, 0.40) * 0.40;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	panel.material = mat

func _populate_history(match_over: bool) -> void:
	for child in history_container.get_children():
		child.queue_free()
	history_panel.visible = match_over
	if not match_over:
		return

	for round_data in GameSession.round_history:
		var parts := []
		var players := GameSession.players
		var sorted_players := players.duplicate()
		sorted_players.sort_custom(func(a, b):
			return round_data.placements.get(a.id, 99) < round_data.placements.get(b.id, 99)
		)
		for p in sorted_players:
			var pl: int = round_data.placements.get(p.id, 99)
			var lbl: String = PLACEMENT_LABELS[mini(pl, PLACEMENT_LABELS.size() - 1)]
			parts.append("%s %s" % [lbl, p.name])
		var row := Label.new()
		row.text = "%s:  %s" % [round_data.game_name, "  |  ".join(PackedStringArray(parts))]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_color_override("font_color", Color(0.85, 0.72, 0.50, 1))
		row.add_theme_font_size_override("font_size", 15)
		history_container.add_child(row)

# ── Effects ───────────────────────────────────────────────────────────────────

func _start_effects() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	SoundManager.play("fanfare")
	_do_flash()
	_animate_entrance()

func _do_flash() -> void:
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.88)
	var t := create_tween()
	t.tween_property(flash_rect, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)

func _animate_entrance() -> void:
	# Title pop-in
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2(0.22, 0.22)
	title_label.modulate.a = 0.0
	var title_tween := create_tween()
	title_tween.tween_property(title_label, "scale", Vector2(1.08, 1.08), 0.42) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	title_tween.parallel().tween_property(title_label, "modulate:a", 1.0, 0.32)
	title_tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.14)

	# Round winner fade
	round_winner_label.modulate.a = 0.0
	var winner_tween := create_tween()
	winner_tween.tween_interval(0.38)
	winner_tween.tween_property(round_winner_label, "modulate:a", 1.0, 0.45)

	# Score cards staggered pop-in
	var cards := scores_container.get_children()
	var num_cards: int = cards.size()
	for i in num_cards:
		var card := cards[i] as Control
		if card == null:
			continue
		card.modulate.a = 0.0
		card.scale = Vector2(0.50, 0.50)
		card.pivot_offset = card.size * 0.5
		var card_tween := create_tween()
		card_tween.tween_interval(0.56 + i * 0.22)
		card_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.40) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		card_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.30)

	# Confetti burst after cards settle
	var confetti_delay: float = 0.56 + num_cards * 0.22 + 0.55
	var confetti_tween := create_tween()
	confetti_tween.tween_interval(confetti_delay)
	confetti_tween.tween_callback(func() -> void:
		var screen_size := get_viewport_rect().size
		confetti_left.global_position = Vector2(0, screen_size.y * 0.28)
		confetti_right.global_position = Vector2(screen_size.x, screen_size.y * 0.28)
		confetti_left.emitting = true
		confetti_right.emitting = true
	)

	# Extra fireworks burst for match winner
	if _match_over:
		var fireworks_tween := create_tween()
		fireworks_tween.tween_interval(confetti_delay + 1.8)
		fireworks_tween.tween_callback(func() -> void:
			confetti_left.restart()
			confetti_right.restart()
		)

# ── Buttons ───────────────────────────────────────────────────────────────────

func _on_rematch_pressed() -> void:
	SoundManager.play("ui_click")
	GameSession.rematch()

func _on_continue_pressed() -> void:
	SoundManager.play("ui_click")
	if GameSession.is_match_over():
		GameSession.go_to("res://scenes/main_menu.tscn")
	else:
		GameSession.go_to("res://scenes/board.tscn")
