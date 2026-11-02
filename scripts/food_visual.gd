class_name FoodVisual
extends RefCounted
## Builds oversized, appetizing food meshes. Origin = bottom center.

const COLORS := {
	"pizza": Color("#ffb703"), "soup": Color("#f77f00"), "burger": Color("#8d5524"),
	"drinks": Color("#e63946"), "icecream": Color("#ffafcc"), "sushi": Color("#ffffff"),
	"cake": Color("#fff0f5"), "jelly": Color("#80ed99"), "coffee": Color("#6f4e37"),
}


## Returns the root node. If the food has a liquid surface, it is stored as meta "liquid".
const SCALE := 1.35  # oversized on purpose: the food is the star of the camera


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * SCALE
	match kind:
		"pizza":
			U.box(root, Vector3(0.55, 0.11, 0.55), Color("#f1e3c8"), Vector3(0, 0.055, 0))
			U.box(root, Vector3(0.56, 0.115, 0.14), Color("#e63946"), Vector3(0, 0.055, 0))
			var tag := U.box(root, Vector3(0.18, 0.005, 0.18), Color("#ffffff"), Vector3(0.15, 0.113, 0.15))
			tag.rotation.y = 0.4
		"soup":
			U.cyl(root, 0.26, 0.26, 0.03, Color("#cfd8dc"), Vector3(0, 0.015, 0))  # tray
			_open(U.cyl(root, 0.24, 0.15, 0.19, Color("#fafafa"), Vector3(0, 0.125, 0)))  # bowl
			var surf := U.cyl(root, 0.215, 0.215, 0.02, Color("#f77f00"), Vector3(0, 0.19, 0))
			root.set_meta("liquid", surf)
			U.sphere(root, 0.035, Color("#2a9d8f"), Vector3(0.05, 0.205, 0.04))
			U.sphere(root, 0.03, Color("#2a9d8f"), Vector3(-0.07, 0.205, -0.02))
		"burger":
			U.cyl(root, 0.22, 0.2, 0.08, Color("#e9a03b"), Vector3(0, 0.04, 0))
			U.cyl(root, 0.23, 0.23, 0.06, Color("#5a2e0e"), Vector3(0, 0.11, 0))
			U.box(root, Vector3(0.42, 0.02, 0.42), Color("#ffd60a"), Vector3(0, 0.15, 0)).rotation.y = 0.78
			U.cyl(root, 0.24, 0.24, 0.025, Color("#52b788"), Vector3(0, 0.175, 0))
			U.cyl(root, 0.23, 0.23, 0.05, Color("#5a2e0e"), Vector3(0, 0.21, 0))
			U.sphere(root, 0.22, Color("#e9a03b"), Vector3(0, 0.25, 0)).scale = Vector3(1, 0.45, 1)
		"drinks":
			U.box(root, Vector3(0.5, 0.03, 0.3), Color("#adb5bd"), Vector3(0, 0.015, 0))
			for i in 3:
				var x := -0.16 + i * 0.16
				U.cyl(root, 0.065, 0.05, 0.22, Color(1, 1, 1, 0.6), Vector3(x, 0.14, 0))
				var c: Color = [Color("#e63946"), Color("#7b2cbf"), Color("#ff9f1c")][i]
				var s := U.cyl(root, 0.06, 0.06, 0.015, c, Vector3(x, 0.24, 0))
				if i == 1:
					root.set_meta("liquid", s)
				U.cyl(root, 0.008, 0.008, 0.18, Color("#ffffff"), Vector3(x + 0.02, 0.3, 0)).rotation.z = 0.2
		"icecream":
			U.cyl(root, 0.11, 0.02, 0.22, Color("#d4a373"), Vector3(0, 0.11, 0))
			U.sphere(root, 0.12, Color("#ffafcc"), Vector3(0, 0.25, 0))
			U.sphere(root, 0.1, Color("#bde0fe"), Vector3(0, 0.36, 0))
			U.sphere(root, 0.03, Color("#e63946"), Vector3(0, 0.46, 0))
		"sushi":
			U.box(root, Vector3(0.5, 0.04, 0.3), Color("#3a3a3a"), Vector3(0, 0.02, 0))
			for i in 6:
				var p := Vector3(-0.18 + (i % 3) * 0.18, 0.07, -0.07 + int(i / 3.0) * 0.14)
				U.cyl(root, 0.055, 0.055, 0.06, Color("#1b4332"), p)
				U.cyl(root, 0.045, 0.045, 0.062, Color("#ffffff"), p)
				U.cyl(root, 0.018, 0.018, 0.064, Color("#f4845f"), p)
		"cake":
			U.cyl(root, 0.3, 0.3, 0.03, Color("#dee2e6"), Vector3(0, 0.015, 0))
			U.cyl(root, 0.27, 0.27, 0.2, Color("#fff0f5"), Vector3(0, 0.13, 0))
			U.cyl(root, 0.2, 0.2, 0.16, Color("#ffc8dd"), Vector3(0, 0.31, 0))
			U.cyl(root, 0.13, 0.13, 0.13, Color("#fff0f5"), Vector3(0, 0.455, 0))
			U.sphere(root, 0.04, Color("#e63946"), Vector3(0, 0.55, 0))
			U.box(root, Vector3(0.04, 0.08, 0.02), Color("#222222"), Vector3(-0.03, 0.57, 0))
			U.box(root, Vector3(0.04, 0.08, 0.02), Color("#ffffff"), Vector3(0.03, 0.57, 0))
		"jelly":
			U.cyl(root, 0.28, 0.28, 0.025, Color("#f8f9fa"), Vector3(0, 0.012, 0))  # plate
			var j := U.cyl(root, 0.2, 0.24, 0.24, Color("#80ed99"), Vector3(0, 0.145, 0), 10)
			j.material_override = U.mat(Color(0.5, 0.93, 0.6, 0.8), false, 0.15)
			U.cyl(root, 0.15, 0.2, 0.05, Color("#57cc99"), Vector3(0, 0.29, 0), 10)
			U.sphere(root, 0.045, Color("#e63946"), Vector3(0, 0.34, 0))
		"coffee":
			U.box(root, Vector3(0.36, 0.025, 0.36), Color("#8d6e63"), Vector3(0, 0.012, 0))
			for i in 4:
				var p := Vector3(-0.09 + (i % 2) * 0.18, 0.09, -0.09 + int(i / 2.0) * 0.18)
				_open(U.cyl(root, 0.06, 0.05, 0.15, Color("#fefae0"), p))
				var c := U.cyl(root, 0.055, 0.055, 0.012, Color("#6f4e37"), p + Vector3(0, 0.07, 0))
				if i == 0:
					root.set_meta("liquid", c)
	return root


## Bowls and cups: no lid, both wall sides drawn, so the liquid inside shows.
static func _open(mi: MeshInstance3D) -> void:
	(mi.mesh as CylinderMesh).cap_top = false
	var m: StandardMaterial3D = mi.material_override.duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m


## Collision shape approximating the food, for when it becomes a loose physics object.
static func shape(kind: String) -> Shape3D:
	var d: Dictionary = FoodItem.DEFS[kind]
	var b := BoxShape3D.new()
	var w := 0.5
	if kind == "icecream":
		w = 0.24
	b.size = Vector3(w, maxf(0.12, d.height), minf(w, 0.45)) * SCALE
	return b


## Rising steam; the rack stops it when the food gets cold.
static func steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.9
	p.local_coords = true
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.04
	m.height = 0.08
	m.radial_segments = 6
	m.rings = 3
	m.material = U.mat(Color(1, 1, 1, 0.35), true)
	p.mesh = m
	return p
