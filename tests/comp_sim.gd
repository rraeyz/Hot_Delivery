extends Node
## Competitive balance: two bots race for the same orders over several rounds.
##   godot --headless --path . --fixed-fps 60 res://tests/comp_sim.tscn -- --rounds=3

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var run := RunState.new(int(args.get("seed", "8")), 5)
	run.setup_competitive(2)
	for r in int(args.get("rounds", "3")):
		var w := World.new()
		w.setup(run, false, true)
		w.skip_replay = true
		if args.has("len"):
			w.time_left = float(args.len)
		add_child(w)
		await get_tree().process_frame
		var bots := [Autopilot.new(w, w.scooters[0]), Autopilot.new(w, w.scooters[1])]
		var done := {}
		w.shift_ended.connect(func(res): done.merge(res))
		while done.is_empty():
			for i in 2:
				w.scooters[i].external_input = bots[i].drive(1.0 / 60.0)
			await get_tree().physics_frame
		print("ROUND %d cards=%s earned_by=%s wallets=%s deliveries=%d" % [run.day, run.cards, run.earned_by, run.wallets, done.reviews.size()])
		run.end_shift()
		for p in 2:   # each bot buys the cheapest card it can afford
			var shop: Array = run.shops[p].duplicate()
			shop.sort_custom(func(a, b): return RunState.UPGRADES[a].cost < RunState.UPGRADES[b].cost)
			for u in shop:
				if run.buy_for(p, u):
					break
		w.queue_free()
		await get_tree().process_frame
		run.next_day()
	print("COMP DONE winner=team %d earned=%s" % [run.winner(), run.earned_by])
	get_tree().quit(0 if run.earned_by[0] + run.earned_by[1] > 0 else 1)
