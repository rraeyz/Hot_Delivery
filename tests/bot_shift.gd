extends Node
## Integration test: a bot plays full shifts headless.
##   godot --headless --path . --fixed-fps 60 res://tests/bot_shift.tscn -- --days=2 --chaos=rain,dogs
## Catches runtime errors in the whole order -> delivery -> review -> rent loop and
## prints money per shift for balancing.

var fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var days := int(args.get("days", "1"))
	var run := RunState.new(int(args.get("seed", "5")), int(args.get("unlocks", "5")))
	run.theme = args.get("theme", "bazaar")
	for d in days:
		if args.has("chaos"):
			run.chaos = Array(args.chaos.split(","))
		var w := World.new()
		w.setup(run, false)
		if args.has("len"):
			w.time_left = float(args.len)
		if args.has("elevator"):   # broken-elevator event for the whole shift
			w.elevator_until = 1e9
		add_child(w)
		await get_tree().process_frame
		var bot := Autopilot.new(w)
		if args.has("event"):
			w._random_event(args.event)
		if args.has("chatvote"):   # fake chat: everyone votes for option 2
			w.chat_votes = true
			w.event_timer = 21.0
		var result := {}
		w.shift_ended.connect(func(r): result.merge(r))
		var frames := 0
		var expect_event := ""
		while result.is_empty():
			w.scooter.external_input = bot.drive(1.0 / 60.0)
			await get_tree().physics_frame
			frames += 1
			if args.has("chatvote") and frames % 30 == 0 and w.vote.options.size() == 3:
				w.vote.add("viewer%d" % (frames % 7), "2")
				expect_event = w.vote.options[1]
			if args.has("chatvote") and expect_event != "" and w.vote.options.is_empty():
				print("CHATVOTE picked=%s expected=%s" % [w.last_event, expect_event])
				if w.last_event != expect_event:
					fails += 1
				expect_event = ""
			if frames % 300 == 0 and args.has("verbose"):
				print("  t=%d pos=%s spd=%.1f items=%d path=%s goal=%s crashed=%s grounded=%s in=%s up=%s" % [frames / 60, w.scooter.global_position, w.scooter.speed, w.scooter.rack.items.size(), bot.path, bot.goal.round(), w.scooter.is_crashed, w.scooter.grounded, w.scooter.external_input, w.scooter.global_basis.y])
			if bot.stuck_t > 2.0 and frames % 120 == 0:
				var sc := w.scooter
				var q := PhysicsRayQueryParameters3D.create(sc.global_position + Vector3.UP * 0.6, sc.global_position + Vector3.UP * 0.6 - sc.global_basis.z * 3.0)
				q.exclude = [sc.get_rid()]
				var hit := sc.get_world_3d().direct_space_state.intersect_ray(q)
				var near := []
				for c in w.get_children():
					if c is Node3D and c != sc and c.global_position.distance_to(sc.global_position) < 4.0:
						near.append("%s@%s" % [c.get_class(), c.global_position.round()])
				print("  STUCK fwd=%s hit=%s near=%s" % [-sc.global_basis.z, hit.get("collider"), near])
			if frames > 60 * 400:
				printerr("FAIL: shift never ended")
				fails += 1
				break
		var tips := []
		for rv in result.get("reviews", []):
			tips.append(rv.tip)
		print("DAY %d chaos=%s deliveries=%d earned=$%d rent=$%d crashes=%d throws=%d tips=%s" % [run.day, run.chaos, result.get("reviews", []).size(), run.earned_today, run.rent(), run.stats.crashes, run.stats.throws, tips])
		var j: Array = w.debug_log.jolts
		j.sort()
		print("   jolts=%d max=%s median=%s falls=%d crash_speeds=%s" % [j.size(), j.back() if j.size() else 0, j[j.size() / 2] if j.size() else 0, w.debug_log.falls, w.debug_log.crash_speeds])
		for rv in result.get("top", []):
			print("   ", rv.stars, "* ", rv.line)
		if result.get("reviews", []).size() == 0:
			printerr("FAIL: bot delivered nothing")
			fails += 1
		var paid := run.end_shift()
		print("   rent paid: ", paid, " money left: $", run.money)
		w.queue_free()
		await get_tree().process_frame
		if not paid:
			run.money += 1000   # keep testing later days
			run.fired = false
			run.roll_shop()
		if run.shop.size() > 0:
			run.money += 100
			run.buy(run.shop[0])
		run.next_day()
	print("BOT DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
