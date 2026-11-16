extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	await process_frame
	var driver := preload("res://scripts/platform_checks.gd").new()
	root.add_child(driver)
	var result: Dictionary = await driver.run(game)
	print("LANTERN_PLATFORM_TEST_RESULT ", JSON.stringify(result))
	game.shadows.light_depth.release_render_targets()
	for frame in range(4):
		await process_frame
	game.queue_free()
	driver.queue_free()
	await process_frame
	quit(0 if result.failed.is_empty() else 1)
