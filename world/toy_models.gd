extends RefCounted

## Original low-poly toy geometry, reused by play, setup, shop, gallery and shares.

static var _materials: Dictionary = {}


## Factory roots stand on y=0 and face -Z unless the prop is side-on.
static func create(
	kind: String, color: Color = Color("4da3ff"),
	hat: String = "fm_hat_none", character: int = 0
) -> Node3D:
	match kind:
		"crew": return crew(color, hat, character)
		"gator": return gator()
		"mower": return mower(color, hat, character)
		"rocket": return rocket(color, hat, character)
		"flamingo": return flamingo()
		"python": return python()
		"gift": return gift()
		"debris": return debris()
		"party":
			var root := Node3D.new()
			var good := gift()
			good.position.x = -0.65
			root.add_child(good)
			var bad := debris()
			bad.position.x = 0.65
			root.add_child(bad)
			label(root, "+1", Vector3(-0.65, 1.1, 0), Color("fff3d4"))
			label(root, "-1", Vector3(0.65, 1.1, 0), Color("fff3d4"))
			return root
	assert(false, "Unknown Florida Men toy model: " + kind)
	return Node3D.new()


## Materials are immutable shared palette entries, not per-frame allocations.
static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.68
		_materials[color] = result
	return _materials[color]


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, pos, color)


static func ball(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var result := _mesh(parent, mesh, pos, color)
	result.scale = size
	return result


static func cylinder(
	parent: Node3D, radius: float, height: float, pos: Vector3, color: Color,
	top: float = -1.0
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, mesh, pos, color)


static func beam(
	parent: Node3D, from: Vector3, to: Vector3, radius: float, color: Color
) -> MeshInstance3D:
	var result := cylinder(parent, radius, from.distance_to(to), (from + to) * 0.5, color)
	result.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return result


static func label(
	parent: Node3D, text: String, pos: Vector3, color: Color, font_size: int = 40
) -> Label3D:
	var result := Label3D.new()
	result.text = text
	result.position = pos
	result.modulate = color
	result.font_size = font_size
	result.outline_size = 8
	result.outline_modulate = Color("12343d")
	result.pixel_size = 0.01
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(result)
	return result


static func crew(color: Color, hat: String, character: int) -> Node3D:
	var root := Node3D.new()
	root.name = "HolidayGuest"
	var skin: Color = [Color("e1ac80"), Color("a87050"), Color("edc49a"), Color("c48c64")][character % 4]
	var hair: Color = [Color("79472d"), Color("302f34"), Color("c8944f"), Color("574d47")][character % 4]
	ball(root, Vector3(0.53, 0.62, 0.38), Vector3(0, 0.69, 0), color)
	box(root, Vector3(0.46, 0.18, 0.32), Vector3(0, 0.38, 0), Color("314c62"))
	for side in [-1.0, 1.0]:
		cylinder(root, 0.085, 0.28, Vector3(side * 0.13, 0.2, 0), skin)
		box(root, Vector3(0.18, 0.1, 0.3), Vector3(side * 0.13, 0.06, -0.04), Color("f3dfa5"))
		box(root, Vector3(0.185, 0.025, 0.31), Vector3(side * 0.13, 0.025, -0.04), Color("58666b"))
		cylinder(root, 0.075, 0.35, Vector3(side * 0.30, 0.64, 0), skin).rotation.z = side * 0.16
		ball(root, Vector3(0.21, 0.23, 0.30), Vector3(side * 0.25, 0.83, 0), color)
		ball(root, Vector3(0.16, 0.17, 0.16), Vector3(side * 0.33, 0.47, 0), skin)
	ball(root, Vector3(0.51, 0.51, 0.47), Vector3(0, 1.16, 0), skin)
	ball(root, Vector3(0.51, 0.2, 0.47), Vector3(0, 1.35, 0.03), hair)
	for side in [-1.0, 1.0]:
		ball(root, Vector3(0.085, 0.11, 0.06), Vector3(side * 0.105, 1.19, -0.22), Color("23383f"))
		ball(root, Vector3(0.024, 0.03, 0.018),
			Vector3(side * 0.105 + 0.012, 1.215, -0.25), Color("fff3d4"))
		ball(root, Vector3(0.10, 0.14, 0.10), Vector3(side * 0.25, 1.15, 0), skin)
		var collar := box(root, Vector3(0.08, 0.09, 0.03),
			Vector3(side * 0.055, 0.92, -0.13), color.lightened(0.3))
		collar.rotation.z = side * 0.35
	ball(root, Vector3(0.08, 0.09, 0.08), Vector3(0, 1.12, -0.25), skin.lightened(0.06))
	box(root, Vector3(0.13, 0.027, 0.025), Vector3(0, 1.035, -0.215), Color("8c563e"))
	for y in [0.72, 0.84]:
		ball(root, Vector3(0.025, 0.025, 0.018), Vector3(0, y, -0.185), Color("fff3d4"))
	_hat(root, hat, color)
	return root


static func gator() -> Node3D:
	var root := Node3D.new()
	root.name = "ToyGator"
	ball(root, Vector3(0.8, 0.5, 1.6), Vector3(0, 0.35, 0), Color("6caa64"))
	box(root, Vector3(0.62, 0.22, 0.8), Vector3(0, 0.28, -0.9), Color("81b76b"))
	box(root, Vector3(0.61, 0.055, 0.72), Vector3(0, 0.2, -0.94), Color("30594c"))
	for side in [-1.0, 1.0]:
		ball(root, Vector3(0.23, 0.22, 0.24), Vector3(side * 0.23, 0.59, -0.62), Color("fff3d4"))
		ball(root, Vector3(0.09, 0.12, 0.08), Vector3(side * 0.23, 0.6, -0.735), Color("203e42"))
		for z in [-0.5, 0.5]:
			box(root, Vector3(0.35, 0.13, 0.26), Vector3(side * 0.47, 0.13, z), Color("4a8f5c"))
		for z in [-0.8, -1.0, -1.2]:
			box(root, Vector3(0.06, 0.07, 0.07), Vector3(side * 0.26, 0.22, z), Color("fff3d4"))
	var tail := cylinder(root, 0.25, 1.0, Vector3(0, 0.24, 1.05), Color("4a8f5c"), 0.02)
	tail.rotation.x = PI * 0.5
	for z in [-0.3, 0.0, 0.3, 0.6]:
		cylinder(root, 0.11, 0.18, Vector3(0, 0.61, z), Color("3c7855"), 0.0)
	return root


static func mower(color: Color, hat: String, character: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ToyMower"
	box(root, Vector3(1.0, 0.22, 1.35), Vector3(0, 0.32, 0), color)
	box(root, Vector3(0.7, 0.38, 0.5), Vector3(0, 0.62, -0.4), color.lightened(0.18))
	box(root, Vector3(0.45, 0.24, 0.46), Vector3(0, 0.55, 0.32), Color("31434b"))
	for x in [-0.53, 0.53]:
		for z in [-0.43, 0.43]:
			var wheel := cylinder(root, 0.23, 0.16, Vector3(x, 0.22, z), Color("263c43"))
			wheel.rotation.z = PI * 0.5
			ball(root, Vector3(0.04, 0.2, 0.2), Vector3(x * 1.17, 0.22, z), Color("c1c6b4"))
	var driver := crew(color, hat, character)
	driver.scale = Vector3.ONE * 0.65
	driver.position = Vector3(0, 0.57, 0.14)
	root.add_child(driver)
	beam(root, Vector3(0, 0.7, -0.3), Vector3(0, 1.0, -0.1), 0.045, Color("283f46"))
	box(root, Vector3(0.45, 0.05, 0.08), Vector3(0, 1.0, -0.1), Color("283f46"))
	return root


static func rocket(color: Color, hat: String, character: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ToyRocket"
	cylinder(root, 0.26, 1.4, Vector3(0, 0.4, 0), Color("dce5d8")).rotation.z = PI * 0.5
	cylinder(root, 0.26, 0.5, Vector3(0.95, 0.4, 0), color, 0.0).rotation.z = -PI * 0.5
	for z in [-0.32, 0.32]:
		box(root, Vector3(0.65, 0.08, 0.55), Vector3(-0.48, 0.23, z), color)
	cylinder(root, 0.2, 0.6, Vector3(-1.0, 0.4, 0), Color("ef9e50"), 0.0).rotation.z = PI * 0.5
	var driver := crew(color, hat, character)
	driver.scale = Vector3.ONE * 0.56
	driver.position = Vector3(-0.1, 0.55, 0)
	root.add_child(driver)
	return root


static func flamingo() -> Node3D:
	var root := Node3D.new()
	root.name = "ToyFlamingo"
	var pink := Color("ef8fac")
	for x in [-0.11, 0.11]:
		cylinder(root, 0.035, 0.9, Vector3(x, 0.5, 0), Color("c96b86"))
		box(root, Vector3(0.08, 0.035, 0.27), Vector3(x, 0.04, -0.08), Color("dc7b92"))
	ball(root, Vector3(0.6, 0.5, 0.85), Vector3(0, 1.1, 0.07), pink)
	beam(root, Vector3(0, 1.1, -0.2), Vector3(0, 1.7, -0.4), 0.08, pink)
	beam(root, Vector3(0, 1.7, -0.4), Vector3(0, 1.85, -0.15), 0.085, pink)
	ball(root, Vector3(0.27, 0.28, 0.31), Vector3(0, 1.86, -0.23), pink)
	box(root, Vector3(0.14, 0.12, 0.3), Vector3(0, 1.79, -0.46), Color("efd8a5"))
	box(root, Vector3(0.14, 0.13, 0.13), Vector3(0, 1.73, -0.6), Color("263c43"))
	for x in [-0.135, 0.135]:
		ball(root, Vector3(0.04, 0.065, 0.065), Vector3(x, 1.9, -0.31), Color("263c43"))
	return root


static func python() -> Node3D:
	var root := Node3D.new()
	root.name = "ToyPython"
	for index in 2:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22 - index * 0.06
		ring.outer_radius = 0.42 - index * 0.06
		ring.rings = 12
		ring.ring_segments = 8
		_mesh(root, ring, Vector3(0, 0.13 + index * 0.16, 0), Color("76ac64"))
	ball(root, Vector3(0.4, 0.28, 0.48), Vector3(0, 0.39, -0.28), Color("89bb73"))
	for x in [-0.13, 0.13]:
		ball(root, Vector3(0.08, 0.1, 0.07), Vector3(x, 0.48, -0.42), Color("fff3d4"))
		ball(root, Vector3(0.035, 0.055, 0.04), Vector3(x, 0.48, -0.455), Color("263c43"))
	return root


static func gift() -> Node3D:
	var root := Node3D.new()
	root.name = "PartyGift"
	box(root, Vector3(0.55, 0.55, 0.55), Vector3(0, 0.3, 0), Color("ef8fac"))
	box(root, Vector3(0.1, 0.57, 0.57), Vector3(0, 0.3, 0), Color("fff3d4"))
	box(root, Vector3(0.57, 0.57, 0.1), Vector3(0, 0.3, 0), Color("fff3d4"))
	return root


static func debris() -> Node3D:
	var root := Node3D.new()
	root.name = "WoodenDebris"
	for index in 3:
		box(root, Vector3(0.75, 0.1, 0.18), Vector3(0, 0.1 + index * 0.1, 0),
			Color("9a7656")).rotation.y = index * 0.8
	return root


static func trap(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CatchCrate"
	box(root, Vector3(0.7, 0.08, 0.7), Vector3(0, 0.05, 0), Color("a48255"))
	for side in [-1.0, 1.0]:
		box(root, Vector3(0.08, 0.25, 0.7), Vector3(side * 0.34, 0.2, 0), color)
		box(root, Vector3(0.7, 0.25, 0.08), Vector3(0, 0.2, side * 0.34), color)
	return root


static func palm(parent: Node3D, pos: Vector3, scale_value: float = 1.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.scale = Vector3.ONE * scale_value
	cylinder(root, 0.16, 2.6, Vector3(0, 1.3, 0), Color("aa7b51"), 0.09)
	for index in 6:
		var leaf := box(root, Vector3(0.32, 0.08, 1.6),
			Vector3(sin(index * TAU / 6) * 0.6, 2.55, cos(index * TAU / 6) * 0.6),
			Color("4d9d70"))
		leaf.rotation = Vector3(0.23, index * TAU / 6, 0)
	for x in [-0.16, 0.16]:
		ball(root, Vector3.ONE * 0.27, Vector3(x, 2.3, 0), Color("795c43"))
	return root


static func chair(parent: Node3D, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	box(root, Vector3(0.65, 0.1, 0.6), Vector3(0, 0.4, 0), Color("e6c095"))
	box(root, Vector3(0.65, 0.65, 0.08), Vector3(0, 0.76, 0.27), Color("e6c095"))
	for x in [-0.24, 0.24]:
		for z in [-0.22, 0.22]:
			cylinder(root, 0.035, 0.4, Vector3(x, 0.2, z), Color("727f77"))
	return root


static func chicken() -> Node3D:
	var root := Node3D.new()
	root.name = "ToyChicken"
	ball(root, Vector3(0.45, 0.4, 0.55), Vector3(0, 0.3, 0), Color("fff3d4"))
	ball(root, Vector3.ONE * 0.28, Vector3(0, 0.55, -0.2), Color("fff3d4"))
	box(root, Vector3(0.12, 0.08, 0.17), Vector3(0, 0.53, -0.39), Color("ef9e50"))
	box(root, Vector3(0.08, 0.13, 0.16), Vector3(0, 0.74, -0.2), Color("df6570"))
	return root


static func _hat(parent: Node3D, id: String, color: Color) -> void:
	var y := 1.4
	match id:
		"fm_hat_none": pass
		"fm_hat_straw":
			cylinder(parent, 0.4, 0.06, Vector3(0, y, 0), Color("e4bd76"))
			cylinder(parent, 0.25, 0.23, Vector3(0, y + 0.13, 0), Color("e4bd76"))
			cylinder(parent, 0.26, 0.065, Vector3(0, y + 0.06, 0), color)
		"fm_hat_party":
			cylinder(parent, 0.27, 0.6, Vector3(0, y + 0.27, 0), Color("ef8fac"), 0.0)
			cylinder(parent, 0.23, 0.05, Vector3(0, y + 0.1, 0), Color("fff3d4"), 0.2)
			ball(parent, Vector3.ONE * 0.15, Vector3(0, y + 0.6, 0), color)
		"fm_hat_rain":
			cylinder(parent, 0.38, 0.06, Vector3(0, y, 0), Color("f6c453"))
			cylinder(parent, 0.29, 0.24, Vector3(0, y + 0.14, 0), Color("f6c453"), 0.23)
		"fm_hat_propeller":
			ball(parent, Vector3(0.52, 0.26, 0.47), Vector3(0, y, 0), color)
			cylinder(parent, 0.035, 0.24, Vector3(0, y + 0.16, 0), Color("e4bd76"))
			box(parent, Vector3(0.85, 0.04, 0.1), Vector3(0, y + 0.29, 0), Color("ef8fac"))
			box(parent, Vector3(0.1, 0.04, 0.7), Vector3(0, y + 0.29, 0), Color("f6c453"))
		_: assert(false, "Unknown Florida Men hat: " + id)


static func _mesh(
	parent: Node3D, mesh: Mesh, pos: Vector3, color: Color
) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = material(color)
	result.position = pos
	parent.add_child(result)
	return result
