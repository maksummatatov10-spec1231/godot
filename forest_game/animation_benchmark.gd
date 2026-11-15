extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world = load("res://world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.player.set_physics_process(false)
	world.player.set_process(false)
	var rows = []
	for first in [false, true]:
		world.player.set_first_person(first)
		for warm in range(100):
			world.player.advance_animation(1.0 / 60.0)
		var timings = []
		for repeat in range(7):
			var start = Time.get_ticks_usec()
			for frame in range(500):
				world.player.advance_animation(1.0 / 60.0)
			timings.append((Time.get_ticks_usec() - start) / 500.0)
		timings.sort()
		rows.append(
			{"first_person": first, "animation_cpu_us_median": timings[3], "samples_us": timings}
		)
	print("PERF_PROBE ", JSON.stringify(rows))
	await world.stop_audio()
	quit()
