extends SceneTree
## Headless test runner:  godot --headless --path . -s tests/run_tests.gd
## Exits with code 1 if any check fails.

var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			var scr: GDScript = load("res://tests/" + f)
			if scr == null or not scr.can_instantiate():
				check(false, "test file failed to compile: " + f)
				continue
			var t: Object = scr.new()
			for m in t.get_method_list():
				var mname: String = m.name
				if mname.begins_with("test_"):
					t.call(mname, self)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
