extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var expected := OS.get_environment("LANTERN_EXPECTED_PROFILE")
	var options: Node = game.platform_options
	var passed: bool = options.mobile == (expected == "android")
	passed = passed and Engine.max_fps == (60 if options.mobile else 75)
	passed = (
		passed
		and (
			root.content_scale_mode
			== (
				Window.CONTENT_SCALE_MODE_VIEWPORT
				if options.mobile
				else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			)
		)
	)
	passed = (
		passed
		and (
			ProjectSettings.get_setting("display/window/size/window_width_override")
			== (1280 if options.mobile else 1920)
		)
	)
	print(
		"LANTERN_PROFILE_RESULT ",
		JSON.stringify(
			{
				"passed": passed,
				"expected": expected,
				"mobile": options.mobile,
				"cap": Engine.max_fps
			}
		)
	)
	game.shadows.light_depth.release_render_targets()
	for frame in range(4):
		await process_frame
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
