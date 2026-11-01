class_name FoodVisual
extends RefCounted
## Builds oversized, appetizing food meshes. Origin = bottom center.

const COLORS := {
	"pizza": Color("#ffb703"), "soup": Color("#f77f00"), "burger": Color("#8d5524"),
	"drinks": Color("#e63946"), "icecream": Color("#ffafcc"), "sushi": Color("#ffffff"),
	"cake": Color("#fff0f5"),
}


## Returns the root node. If the food has a liquid surface, it is stored as meta "liquid".
static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"pizza":
			U.box(root, Vector3(0.55, 0.11, 0.55), Color("#d9a066"), Vector3(0, 0.055, 0))
			U.box(root, Vector3(0.56, 0.02, 0.2), Color("#e63946"), Vector3(0, 0.1, 0))
			var tag := U.box(root, Vector3(0.18, 0.005, 0.18), Color("#ffffff"), Vector3(0.15, 0.113, 0.15))
			tag.rotation.y = 0.4
		"soup":
			U.cyl(root, 0.26, 0.26, 0.03, Color("#cfd8dc"), Vector3(0, 0.015, 0))  # tray
			U.cyl(root, 0.24, 0.15, 0.19, Color("#fafafa"), Vector3(0, 0.125, 0))  # bowl
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
	return root


## Collision shape approximating the food, for when it becomes a loose physics object.
static func shape(kind: String) -> Shape3D:
	var d: Dictionary = FoodItem.DEFS[kind]
	var b := BoxShape3D.new()
	var w := 0.5
	if kind == "icecream":
		w = 0.24
	b.size = Vector3(w, maxf(0.12, d.height), minf(w, 0.45))
	return b
