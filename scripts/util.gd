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


static var _vc_mat: StandardMaterial3D


## One shared material that takes its color from the vertices (lets many colors share a draw call).
static func vc_material() -> StandardMaterial3D:
	if not _vc_mat:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.roughness = 0.75
	return _vc_mat


static func _plain(m: Material) -> bool:
	return m is StandardMaterial3D and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
		and not m.emission_enabled and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL


## Merge MeshInstance3D nodes into few meshes, relative to `rel_to`.
## Plain colored materials collapse into one vertex-colored mesh per key; others keep their material.
## key_fn(mi) -> String splits groups (e.g. by city chunk). Returns the new MeshInstance3D nodes (unparented).
static func merge(meshes: Array, rel_to: Node, key_fn := Callable()) -> Array:
	var groups := {}
	for mi in meshes:
		var mat: Material = mi.material_override
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv = arr[Mesh.ARRAY_TEX_UV]
		var idx = arr[Mesh.ARRAY_INDEX]
		var plain := _plain(mat)
		var key: String = ("vc" if plain else str(mat.get_instance_id())) + ("_" + str(key_fn.call(mi)) if key_fn.is_valid() else "")
		if not groups.has(key):
			groups[key] = {"mat": vc_material() if plain else mat, "v": PackedVector3Array(), "n": PackedVector3Array(),
				"uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
		var g: Dictionary = groups[key]
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p and p != rel_to:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var nb: Basis = xf.basis.inverse().transposed()
		var col: Color = (mat as StandardMaterial3D).albedo_color if plain else Color.WHITE
		var base: int = g.v.size()
		var gv: PackedVector3Array = g.v
		var gn: PackedVector3Array = g.n
		var gc: PackedColorArray = g.c
		var gu: PackedVector2Array = g.uv
		var gi: PackedInt32Array = g.i
		for k in v.size():
			gv.append(xf * v[k])
			gn.append((nb * nrm[k]).normalized())
			gc.append(col)
		if uv is PackedVector2Array and uv.size() == v.size():
			gu.append_array(uv)
		else:
			gu.resize(gv.size())
		if idx is PackedInt32Array and idx.size() > 0:
			for k in idx:
				gi.append(base + k)
		else:
			for k in v.size():
				gi.append(base + k)
		g.v = gv
		g.n = gn
		g.c = gc
		g.uv = gu
		g.i = gi
	var out := []
	for key in groups:
		var g: Dictionary = groups[key]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = g.v
		a[Mesh.ARRAY_NORMAL] = g.n
		a[Mesh.ARRAY_TEX_UV] = g.uv
		a[Mesh.ARRAY_COLOR] = g.c
		a[Mesh.ARRAY_INDEX] = g.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var m := MeshInstance3D.new()
		m.mesh = am
		m.material_override = g.mat
		out.append(m)
	return out


## Collapse all simple child meshes of a moving object (car, prop, pedestrian) into one or two meshes.
static func bake(root: Node3D) -> void:
	var list := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if mi.get_child_count() == 0 and mi.mesh and mi.material_override and mi.mesh.get_surface_count() == 1:
			list.append(mi)
	if list.size() < 2:
		return
	for m in merge(list, root):
		root.add_child(m)
	for mi in list:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
