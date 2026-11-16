extends SceneTree
## Reproducible shadow CPU / optional rendered frame timings; never a physical GPU claim.
var game: Node2D
var samples: Array[Dictionary] = []
var rendered := false
var output := ""


func _initialize() -> void:
	output = OS.get_environment("BENCH_DIR")
	assert(not output.is_empty())
	rendered = OS.get_environment("BENCH_RENDERED") == "1"
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(int(float(sorted.size() - 1) * fraction), sorted.size() - 1)]


func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	for warm in range(4):
		await process_frame
	game.resume()
	game.mode = "capture"
	game.camera.position_smoothing_enabled = false
	game.camera.limit_enabled = false
	game.camera.zoom = Vector2.ONE
	game.set_process(false)
	game.shadows.set_process(false)
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	for label in ["village", "forest", "farm"]:
		var center := Vector2(game.map.views[label][0], game.map.views[label][1])
		game.camera.position = center
		game.camera.reset_smoothing()
		game.camera.force_update_scroll()
		var times: Array[float] = []
		var frame_times: Array[float] = []
		var draws: Array[float] = []
		for index in range(140):
			game.elapsed += 1.0 / 60.0
			game.hero.position = center + Vector2(float(index % 40) * 0.75 - 15, 0)
			game.hero.state = "walk"
			game.hero.clock = game.elapsed
			game.hero.animate()
			var start := Time.get_ticks_usec()
			game.shadows._process(1.0 / 60.0)
			var duration := float(Time.get_ticks_usec() - start) / 1000.0
			if rendered:
				game.overlays.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
			if index >= 20:
				times.append(duration)
				frame_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
				draws.append(
					float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				)
		var row := {
			"view": label,
			"samples": times.size(),
			"shadow_cpu_ms_median": percentile(times, 0.5),
			"shadow_cpu_ms_p95": percentile(times, 0.95),
			"rendered_frame_ms_median": percentile(frame_times, 0.5) if rendered else 0.0,
			"rendered_frame_ms_p95": percentile(frame_times, 0.95) if rendered else 0.0,
			"draw_calls_median": percentile(draws, 0.5) if rendered else 0.0
		}
		if game.shadows.has_method("performance_stats"):
			row["shadow_work"] = game.shadows.performance_stats()
		samples.append(row)
		print("BENCH ", JSON.stringify(row))
	var file := FileAccess.open(output.path_join("benchmark.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{"rendered": rendered, "physical_gpu_benchmark": false, "views": samples}, "\t"
		)
	)
	file.close()
	print("LANTERN_BENCH_OK")
	game.tone_player.stop()
	game.ambience_player.stop()
	game.shadows.light_depth.release_render_targets()
	for release_frame in range(4):
		await process_frame
	game.queue_free()
	create_timer(0.2).timeout.connect(quit)
