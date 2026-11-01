class_name Courier
extends RefCounted
## Builds the customizable courier. A "look" is a small Dictionary that is saved
## in settings and (later) sent to other players online.

const SKINS := ["#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#5c3a1e", "#ffdbac"]
const JACKETS := ["#ff6b35", "#4361ee", "#2a9d8f", "#e63946", "#ffbe0b", "#8338ec", "#ff70a6", "#222222", "#f8f9fa"]
const HELMETS := ["classic", "cat", "chef", "pirate", "cap", "viking", "bunny", "none"]
const ACCESSORIES := ["none", "glasses", "mustache", "scarf", "bowtie", "beard"]
const SLOTS := {"skin": SKINS, "jacket": JACKETS, "helmet": HELMETS, "helmet_color": JACKETS, "accessory": ACCESSORIES}


const NAMES_TR := {"classic": "klasik", "cat": "kedi", "chef": "şef", "pirate": "korsan", "cap": "şapka",
	"viking": "viking", "bunny": "tavşan", "none": "yok", "glasses": "gözlük", "mustache": "bıyık",
	"scarf": "atkı", "bowtie": "papyon", "beard": "sakal"}


static func label(v: String, lang: String) -> String:
	return NAMES_TR.get(v, v) if lang == "tr" else v


static func default_look(player := 0) -> Dictionary:
	return {"skin": 0, "jacket": player % JACKETS.size(), "helmet": 0, "helmet_color": (player + 1) % JACKETS.size(), "accessory": 0}


## Cycles one slot by +1/-1 and returns the new look.
static func cycle(look: Dictionary, slot: String, dir: int) -> Dictionary:
	var l := look.duplicate()
	var n: int = SLOTS[slot].size()
	l[slot] = posmod(int(l.get(slot, 0)) + dir, n)
	return l


static func build(parent: Node3D, look: Dictionary, standing := false) -> void:
	var skin := Color(SKINS[int(look.get("skin", 0)) % SKINS.size()])
	var jacket := Color(JACKETS[int(look.get("jacket", 0)) % JACKETS.size()])
	var hc := Color(JACKETS[int(look.get("helmet_color", 1)) % JACKETS.size()])
	var helmet: String = HELMETS[int(look.get("helmet", 0)) % HELMETS.size()]
	var acc: String = ACCESSORIES[int(look.get("accessory", 0)) % ACCESSORIES.size()]
	# torso: rounded capsule
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.21
	cm.height = 0.62
	torso.mesh = cm
	torso.material_override = U.mat(jacket, false, 0.7)
	torso.position = Vector3(0, 0.32, 0)
	parent.add_child(torso)
	U.box(parent, Vector3(0.36, 0.05, 0.02), Color("#f8f9fa"), Vector3(0, 0.36, 0.205))  # reflective stripe
	U.sphere(parent, 0.17, skin, Vector3(0, 0.78, -0.01))  # head
	# eyes look forward (-Z)
	for x in [-0.06, 0.06]:
		U.sphere(parent, 0.028, Color("#1d1d1d"), Vector3(x, 0.8, -0.16))
	if standing:
		# arms hanging, legs straight down (pedestrians)
		for x in [-0.26, 0.26]:
			U.cyl(parent, 0.06, 0.055, 0.5, jacket, Vector3(x, 0.32, 0))
			U.sphere(parent, 0.06, skin, Vector3(x, 0.05, 0))
		for x in [-0.1, 0.1]:
			U.cyl(parent, 0.075, 0.07, 0.6, Color("#264653"), Vector3(x, -0.25, 0))
			U.box(parent, Vector3(0.12, 0.08, 0.22), Color("#1d1d1d"), Vector3(x, -0.55, -0.04))
	else:
		# arms reaching for the handlebar + hands
		for x in [-0.25, 0.25]:
			var arm := U.cyl(parent, 0.065, 0.06, 0.5, jacket, Vector3(x, 0.42, -0.25))
			arm.rotation.x = 1.15
			U.sphere(parent, 0.065, skin, Vector3(x * 1.05, 0.33, -0.48))
		for x in [-0.12, 0.12]:
			var leg := U.cyl(parent, 0.075, 0.07, 0.5, Color("#264653"), Vector3(x, 0.02, -0.18))
			leg.rotation.x = 1.3
			U.box(parent, Vector3(0.12, 0.08, 0.2), Color("#1d1d1d"), Vector3(x, -0.12, -0.42))  # shoes
	match helmet:
		"classic":
			U.sphere(parent, 0.2, hc, Vector3(0, 0.86, 0)).scale = Vector3(1, 0.75, 1.05)
			U.box(parent, Vector3(0.3, 0.07, 0.05), Color("#222222"), Vector3(0, 0.84, -0.17))
		"cat":
			U.sphere(parent, 0.2, hc, Vector3(0, 0.86, 0)).scale = Vector3(1, 0.75, 1.05)
			for x in [-0.11, 0.11]:
				var ear := U.cyl(parent, 0.0, 0.07, 0.14, hc, Vector3(x, 1.02, 0.02), 4)
				ear.rotation.z = -x * 2.0
		"chef":
			U.cyl(parent, 0.15, 0.15, 0.22, Color.WHITE, Vector3(0, 0.98, 0))
			U.sphere(parent, 0.19, Color.WHITE, Vector3(0, 1.1, 0)).scale = Vector3(1, 0.6, 1)
		"pirate":
			U.cyl(parent, 0.26, 0.26, 0.05, Color("#1d1d1d"), Vector3(0, 0.9, 0))
			U.cyl(parent, 0.14, 0.17, 0.16, Color("#1d1d1d"), Vector3(0, 0.99, 0))
			U.box(parent, Vector3(0.08, 0.06, 0.02), Color.WHITE, Vector3(0, 1.0, -0.17))
		"cap":
			U.sphere(parent, 0.18, hc, Vector3(0, 0.88, 0)).scale = Vector3(1, 0.6, 1)
			U.box(parent, Vector3(0.22, 0.02, 0.18), hc.darkened(0.2), Vector3(0, 0.88, -0.2))
		"viking":
			U.sphere(parent, 0.2, Color("#adb5bd"), Vector3(0, 0.86, 0)).scale = Vector3(1, 0.75, 1.05)
			for x in [-1.0, 1.0]:
				var horn := U.cyl(parent, 0.0, 0.05, 0.25, Color("#fefae0"), Vector3(x * 0.22, 0.98, 0), 8)
				horn.rotation.z = -x * 0.7
		"bunny":
			U.sphere(parent, 0.2, hc, Vector3(0, 0.86, 0)).scale = Vector3(1, 0.75, 1.05)
			for x in [-0.07, 0.07]:
				U.sphere(parent, 0.06, hc, Vector3(x, 1.12, 0.02)).scale = Vector3(0.7, 2.6, 0.5)
	match acc:
		"glasses":
			for x in [-0.065, 0.065]:
				var g := U.cyl(parent, 0.045, 0.045, 0.02, Color("#1d1d1d"), Vector3(x, 0.8, -0.17))
				g.rotation.x = PI / 2
		"mustache":
			U.box(parent, Vector3(0.16, 0.035, 0.04), Color("#3b2416"), Vector3(0, 0.73, -0.165))
		"scarf":
			U.cyl(parent, 0.17, 0.19, 0.08, Color("#e63946"), Vector3(0, 0.63, 0))
			U.box(parent, Vector3(0.08, 0.25, 0.03), Color("#e63946"), Vector3(0.08, 0.5, 0.17))
		"bowtie":
			U.box(parent, Vector3(0.14, 0.06, 0.03), Color("#e63946"), Vector3(0, 0.62, -0.19))
		"beard":
			U.sphere(parent, 0.13, Color("#5c3a1e"), Vector3(0, 0.7, -0.08)).scale = Vector3(1, 0.8, 0.8)
