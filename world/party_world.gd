extends Control

## Isolated Compatibility world: only models and cameras, never game rules.

const Toys = preload("res://games/florida_men/world/toy_models.gd")
const Data = preload("res://games/florida_men/data/party_data.gd")

var viewport: SubViewport
var camera: Camera3D
var mode := ""
var reduced_motion := false
var _container: SubViewportContainer
var _stage: Node3D
var _content: Node3D
var _actors: Array[Node3D] = []
var _tags: Array[Label3D] = []
var _moving: Dictionary = {}
var _obstacles: Array[Array] = []
var _finishes: Array[Node3D] = []
var _names: Array[String] = []
var _hats: Array[String] = []
var _characters: Array[int] = []
var _die: Label3D
var _camera_offset := Vector3(0, 15, 13)
var _target := Vector3.ZERO
var _min_height := 14.0
var _min_width := 18.0
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _auto_spin := false
var _spin := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container = SubViewportContainer.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(viewport)
	_stage = Node3D.new()
	viewport.add_child(_stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("98cdd1")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff3d4")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	_stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color("fff1d2")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	_stage.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 150.0
	_stage.add_child(camera)
	resized.connect(_frame_camera)
	_frame_camera()


func _process(delta: float) -> void:
	if _auto_spin and not reduced_motion and _content != null:
		_spin += delta * 0.18
		_content.rotation.y = _spin


## Equipment is supplied by the owning scene, not read from a global store.
func set_roster(names: Array[String], hats: Array[String], characters: Array[int]) -> void:
	_names = names.duplicate()
	_hats = hats.duplicate()
	_characters = characters.duplicate()


func show_board() -> void:
	_clear("board")
	_camera_offset = Vector3(0, 17, 15)
	_target = Vector3(0, 0.4, 0)
	_min_height = 17.0
	_min_width = 19.0
	_build_board()
	for player in 4:
		_add_actor(player, "crew", 0.8)
	_frame_camera()


## Essential token travel remains active with Reduced motion; decorative hops do not.
func sync_board(match_state: RefCounted, roll: Dictionary, fraction: float) -> void:
	var positions: Array = match_state.get("positions")
	for player in 4:
		var tile := _tile_position(int(positions[player]))
		if not roll.is_empty() and int(roll["player"]) == player:
			var travel := float(roll["die"]) * clampf(fraction, 0.0, 1.0)
			var whole := floori(travel)
			var part := travel - whole
			tile = _tile_position((int(roll["from"]) + whole) % 24).lerp(
				_tile_position((int(roll["from"]) + whole + 1) % 24), part)
			if not reduced_motion:
				tile.y += sin(part * PI) * 0.4
		_actors[player].position = tile + Vector3(
			(-0.25 if player % 2 == 0 else 0.25), 0.26,
			(-0.25 if player < 2 else 0.25))
		_tags[player].text = "P%d" % (player + 1)
	if _die != null:
		_die.text = "ROLL %d" % int(roll["die"]) if not roll.is_empty() else "FLORIDA MEN"


func show_minigame(game: String) -> void:
	_clear(game)
	_camera_offset = Vector3(0, 16, 11)
	_target = Vector3.ZERO
	_min_height = 12.0
	_min_width = 17.5
	match game:
		"alligator_wrangler", "python_hunt":
			var count := 8 if game == "alligator_wrangler" else 12
			var cell := 1.0 if count == 8 else 0.8
			_min_height = 10.8 if count == 8 else 11.6
			_min_width = 12.0 if count == 8 else 13.4
			for y in count:
				for x in count:
					var pos := _grid(Vector2(x, y), count)
					var color := Color("b8c5a5") if (x + y) % 2 == 0 else Color("8ba998")
					Toys.box(_content, Vector3(cell * 0.97, 0.16, cell * 0.97), pos, color)
			_scenery(5.2 if count == 8 else 6.0)
			for player in 4:
				_add_actor(player, "crew", 0.62 if count == 8 else 0.5)
		"lawnmower_race":
			_min_height = 15.0
			Toys.box(_content, Vector3(18, 0.2, 20), Vector3(0, -0.15, 0), Color("93b68b"))
			for player in 4:
				var x := (player - 1.5) * 4.0
				Toys.box(_content, Vector3(3.35, 0.12, 19), Vector3(x, 0, 0), Color("677d70"))
				for line in [-0.525, 0.525]:
					for dash in 9:
						Toys.box(_content, Vector3(0.035, 0.025, 0.7),
							Vector3(x + line, 0.08, dash * 2.0 - 8), Color("e6d9ab"))
				_add_actor(player, "mower", 0.8)
				var finish := Node3D.new()
				_content.add_child(finish)
				for square in 6:
					Toys.box(finish, Vector3(0.55, 0.04, 0.5),
						Vector3(x - 1.4 + square * 0.55, 0.11, 0),
						Color("fff3d4") if square % 2 == 0 else Color("263c43"))
				_finishes.append(finish)
				_obstacles.append([])
			_scenery()
		"hurricane_party":
			_side_stage()
			for player in 4:
				_add_actor(player, "crew", 0.9)
			Toys.palm(_content, Vector3(-8.6, 0, -1.5), 1.1)
			Toys.palm(_content, Vector3(8.6, 0, -1.5), 1.1)
		"rocket_man":
			_side_stage()
			_target.x = 8.0
			_camera_offset = Vector3(0, 8, 24)
			_min_height = 14.0
			Toys.box(_content, Vector3(20, 0.4, 11.2), Vector3(8, -0.2, 0), Color("b58c64"))
			var ceiling := Toys.box(_content, Vector3(20, 0.4, 11.2),
				Vector3(8, 10.2, 0), Color("b58c64"))
			ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for player in 4:
				_add_actor(player, "rocket", 0.62)
		"flamingo_fiasco":
			Toys.box(_content, Vector3(17, 0.25, 11), Vector3(0, -0.2, 0), Color("8fba8c"))
			Toys.box(_content, Vector3(5, 0.04, 2.7), Vector3(0, -0.04, 0), Color("66b3bf"))
			_scenery()
			for player in 4:
				_add_actor(player, "crew", 0.8)
	_frame_camera()


## Reuses live nodes; the render tree does not drive collision or timing.
func sync_minigame(state: RefCounted) -> void:
	var positions: Array = state.get("positions")
	var scores: Array = state.get("scores")
	var seen := {}
	for player in 4:
		_tags[player].text = "P%d  %d" % [player + 1, int(scores[player])]
		match mode:
			"alligator_wrangler":
				_actors[player].position = _grid(positions[player], 8) + Vector3(0, 0.12, 0)
			"python_hunt":
				_actors[player].position = _grid(positions[player], 12) + Vector3(0, 0.12, 0)
			"flamingo_fiasco":
				var pos: Vector2 = positions[player]
				_actors[player].position = Vector3(pos.x - 8, 0, pos.y - 5)
			"hurricane_party":
				var pos: Vector2 = positions[player]
				_actors[player].position = Vector3(pos.x - 8, 0, player * 0.08)
			"rocket_man":
				var pos: Vector2 = positions[player]
				var active: bool = state.get("alive")[player]
				# Depth separates pilots without falsifying their shared cave coordinates.
				_actors[player].position = Vector3(pos.x,
					10.0 - clampf(pos.y, 0.0, 10.0) - 0.25, (player - 1.5) * 3.2)
				_actors[player].rotation.z = clampf(-float(state.get("velocity")[player]) * 0.04, -0.3, 0.3)
				_tags[player].text = "P%d %s" % [player + 1, "FLY" if active else "OUT"]
				_actors[player].visible = active
			"lawnmower_race":
				_sync_mower(player, state)
	if mode == "alligator_wrangler":
		var node := _moving_model("gator", "gator", seen)
		node.scale = Vector3.ONE * 0.43
		node.position = _grid(Vector2(state.get("gator")), 8) + Vector3(0, 0.12, 0)
	for entity: Dictionary in state.get("entities"):
		var key := "entity_%d" % int(entity["id"])
		var kind := "flamingo" if mode == "flamingo_fiasco" else "python"
		if mode == "hurricane_party":
			kind = "gift" if entity["good"] else "debris"
		var node := _moving_model(key, kind, seen)
		var pos: Vector2 = entity["pos"]
		match mode:
			"flamingo_fiasco":
				node.scale = Vector3.ONE * 0.65
				node.position = Vector3(pos.x - 8, 0, pos.y - 5)
				var vel: Vector2 = entity["vel"]
				node.rotation.y = atan2(-vel.x, -vel.y)
			"python_hunt":
				node.scale = Vector3.ONE * 0.72
				node.position = _grid(pos, 12) + Vector3(0, 0.12, 0)
			"hurricane_party":
				node.position = Vector3(pos.x - 8, 10.0 - pos.y - 0.3, -0.1)
				if not node.has_meta("marked"):
					Toys.label(node, "+1" if entity["good"] else "-1",
						Vector3(0, 0.85, 0), Color("fff3d4"))
					node.set_meta("marked", true)
	for tile: Vector2i in state.get("traps"):
		var player: int = state.get("traps")[tile]
		var key := "trap_%d_%d" % [tile.x, tile.y]
		seen[key] = true
		if not _moving.has(key):
			var node := Toys.trap(Data.COLORS[player])
			_content.add_child(node)
			node.position = _grid(Vector2(tile), 12) + Vector3(0, 0.12, 0)
			Toys.label(node, "P%d" % (player + 1), Vector3(0, 0.55, 0), Data.COLORS[player], 30)
			_moving[key] = node
	if mode == "rocket_man":
		for wall: Dictionary in state.get("walls"):
			_sync_wall(wall, seen)
	for key: String in _moving.keys():
		if not seen.has(key):
			(_moving[key] as Node3D).queue_free()
			_moving.erase(key)


## Static museum/shop/setup subjects use exactly the same geometry as play.
func show_exhibit(
	kind: String, color: Color = Data.COLORS[0],
	hat: String = "fm_hat_none", character: int = 0
) -> void:
	_clear("exhibit")
	_target = Vector3(0, 0.9, 0)
	_camera_offset = Vector3(3, 2.2, 5)
	_min_height = 3.4
	_min_width = 4.8
	if kind == "board":
		_build_board()
		_target = Vector3.ZERO
		_camera_offset = Vector3(0, 17, 15)
		_min_height = 17.0
		_min_width = 19.0
	else:
		Toys.cylinder(_content, 1.55, 0.16, Vector3(0, -0.12, 0), Color("d3be96"))
		var model := Toys.create(kind, color, hat, character)
		if kind != "rocket":
			model.rotation.y = PI
		_content.add_child(model)
	_frame_camera()


## A frozen share portrait never reads live equipment or an active simulation.
func show_portrait(hats: Array[String], characters: Array[int]) -> void:
	_clear("portrait")
	_build_board()
	for player in 4:
		var actor := Toys.crew(Data.COLORS[player], hats[player], characters[player])
		actor.position = Vector3((player - 1.5) * 2.0, 0.3, 4.6)
		actor.scale = Vector3.ONE * 1.5
		actor.rotation.y = PI
		_content.add_child(actor)
	_target = Vector3(0, 0.6, 1)
	_camera_offset = Vector3(0, 11, 15)
	_min_height = 13.0
	_min_width = 18.0
	_frame_camera()


## Shared gallery gestures supply offsets from the exhibit's authored camera.
func set_view(yaw: float, pitch: float, zoom: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_zoom = zoom
	_frame_camera()


func set_auto_spin(enabled: bool) -> void:
	_auto_spin = enabled


func _frame_camera() -> void:
	if camera == null or size.x < 1.0 or size.y < 1.0:
		return
	var aspect := size.x / size.y
	camera.size = maxf(_min_height, _min_width / aspect) / maxf(_zoom, 0.1)
	var distance := _camera_offset.length()
	var angle := atan2(_camera_offset.z, _camera_offset.x) + _yaw
	var elevation := clampf(asin(_camera_offset.y / distance) + _pitch, 0.12, 1.48)
	var offset := Vector3(cos(angle) * cos(elevation), sin(elevation),
		sin(angle) * cos(elevation)) * distance
	camera.position = _target + offset
	camera.look_at(_target)


func _clear(next: String) -> void:
	if _content != null:
		_stage.remove_child(_content)
		_content.queue_free()
	_content = Node3D.new()
	_stage.add_child(_content)
	mode = next
	_actors.clear()
	_tags.clear()
	_moving.clear()
	_obstacles.clear()
	_finishes.clear()
	_die = null
	_spin = 0.0
	_yaw = 0.0
	_pitch = 0.0
	_zoom = 1.0


func _add_actor(player: int, kind: String, scale_value: float) -> void:
	var actor := Toys.create(kind, Data.COLORS[player], _hats[player], _characters[player])
	actor.scale = Vector3.ONE * scale_value
	if kind == "crew":
		actor.rotation.y = PI
	_content.add_child(actor)
	_actors.append(actor)
	_tags.append(Toys.label(actor, _names[player], Vector3(0, 2.05, 0), Data.COLORS[player]))


func _moving_model(key: String, kind: String, seen: Dictionary) -> Node3D:
	seen[key] = true
	if not _moving.has(key):
		var node := Toys.create(kind)
		_content.add_child(node)
		_moving[key] = node
	return _moving[key]


func _grid(pos: Vector2, count: int) -> Vector3:
	var cell := 1.0 if count == 8 else 0.8
	return Vector3((pos.x - (count - 1) * 0.5) * cell, 0,
		(pos.y - (count - 1) * 0.5) * cell)


func _tile_position(index: int) -> Vector3:
	if index < 8:
		return Vector3(-5.95 + index * 1.7, 0, -4.25)
	if index < 12:
		return Vector3(5.95, 0, -2.55 + (index - 8) * 1.7)
	if index < 20:
		return Vector3(5.95 - (index - 12) * 1.7, 0, 4.25)
	return Vector3(-5.95, 0, 2.55 - (index - 20) * 1.7)


func _build_board() -> void:
	Toys.box(_content, Vector3(20, 0.25, 17), Vector3(0, -0.6, 0), Color("65b6c1"))
	Toys.box(_content, Vector3(15, 0.45, 12), Vector3(0, -0.3, 0), Color("d7c698"))
	Toys.box(_content, Vector3(9.8, 0.18, 6), Vector3(0, -0.03, 0), Color("8db58a"))
	for index in 24:
		var type := Data.SPACE_TYPES[index]
		var pos := _tile_position(index)
		Toys.box(_content, Vector3(1.47, 0.22, 1.47), pos, Data.SPACE_COLORS[type])
		Toys.label(_content, "%02d %s" % [index, Data.SPACE_MARKS[type]],
			pos + Vector3(0, 0.28, 0.48), Color("fff3d4"), 30)
	_die = Toys.label(_content, "FLORIDA MEN", Vector3(0, 2.3, -1), Color("fff3d4"), 64)
	var gator := Toys.gator()
	gator.position = Vector3(-1.6, 0.1, 0)
	gator.rotation.y = -0.4
	_content.add_child(gator)
	var flamingo := Toys.flamingo()
	flamingo.position = Vector3(2.2, 0.1, -0.4)
	_content.add_child(flamingo)
	Toys.chair(_content, Vector3(0.7, 0.1, 1.1))
	for pos in [Vector3(-3.7, 0, -2.0), Vector3(3.8, 0, -2.0),
			Vector3(-3.7, 0, 2.0), Vector3(3.8, 0, 2.0)]:
		Toys.palm(_content, pos, 0.85)


func _scenery(spread: float = 8.6) -> void:
	Toys.palm(_content, Vector3(-spread, 0, -4.7), 0.9)
	Toys.palm(_content, Vector3(spread, 0, -4.7), 0.9)
	Toys.chair(_content, Vector3(-spread, 0, 3.8))
	Toys.chair(_content, Vector3(spread, 0, 3.8))


func _side_stage() -> void:
	_camera_offset = Vector3(0, 1.8, 24)
	_target = Vector3(0, 4.8, 0)
	_min_height = 12.2
	Toys.box(_content, Vector3(40, 0.2, 3), Vector3(0, -0.15, -0.8), Color("d7c698"))


func _sync_mower(player: int, state: RefCounted) -> void:
	var progress: float = state.get("progress")[player]
	var lane: int = state.get("lanes")[player]
	_actors[player].position = Vector3((player - 1.5) * 4 + (lane - 1) * 1.05, 0.1, 4.0)
	_tags[player].text = "P%d %d%%" % [player + 1, roundi(progress / 10.0)]
	var source: Array = state.get("obstacles")[player]
	while _obstacles[player].size() < source.size():
		var obstacle: Dictionary = source[_obstacles[player].size()]
		var node: Node3D
		match int(obstacle["kind"]):
			0:
				node = Node3D.new()
				Toys.box(node, Vector3(0.85, 0.025, 0.8), Vector3.ZERO, Color("9b7652"))
			1: node = Toys.chicken()
			_:
				node = Node3D.new()
				Toys.chair(node, Vector3.ZERO)
		_content.add_child(node)
		_obstacles[player].append(node)
	for index in source.size():
		var obstacle: Dictionary = source[index]
		var node: Node3D = _obstacles[player][index]
		var z := 4.0 - (float(obstacle["progress"]) - progress) * 0.045
		node.position = Vector3((player - 1.5) * 4 + (int(obstacle["lane"]) - 1) * 1.05, 0.1, z)
		node.visible = not obstacle["hit"] and z > -9.0 and z < 7.0
	_finishes[player].position.z = 4.0 - (1000.0 - progress) * 0.045
	_finishes[player].visible = _finishes[player].position.z > -9.0


func _sync_wall(wall: Dictionary, seen: Dictionary) -> void:
	var gap := float(wall["gap"])
	for side in 2:
		var key := "wall_%d_%d" % [int(wall["id"]), side]
		seen[key] = true
		var height := gap - 1.325 if side == 0 else 10.0 - gap - 1.325
		if not _moving.has(key):
			var root := Node3D.new()
			_content.add_child(root)
			Toys.box(root, Vector3(0.32, height, 11.2), Vector3.ZERO, Color("b58c64"))
			Toys.box(root, Vector3(0.4, 0.12, 11.35),
				Vector3(0, -height * 0.5 if side == 0 else height * 0.5, 0), Color("e0bf8e"))
			_moving[key] = root
		var node: Node3D = _moving[key]
		node.position = Vector3(float(wall["x"]),
			10.0 - height * 0.5 if side == 0 else height * 0.5, -0.2)
