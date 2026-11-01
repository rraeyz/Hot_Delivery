class_name U
extends RefCounted
## Tiny helpers for building toy-like meshes from primitives.

static var _mats := {}


static func mat(c: Color, unshaded := false, rough := 0.85) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), unshaded, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func box(parent: Node, size: Vector3, c: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, c: Color, pos := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere(parent: Node, r: float, c: Color, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	mi.mesh = m
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func static_box(parent: Node, size: Vector3, c: Color, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	box(sb, size, c)
	parent.add_child(sb)
	return sb


static func label3d(parent: Node, text: String, pos: Vector3, size := 64, c := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 14
	l.font = UiKit.font(900)
	l.modulate = c
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	parent.add_child(l)
	return l
