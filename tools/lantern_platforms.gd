extends SceneTree
## Genuine PC FullHD and simulated mobile-budget viewport captures; not Android OS evidence.
var game: Node2D
var output := ""
var images: Array = []
var overflows: Array[String] = []


func _initialize() -> void:
	output = OS.get_environment("PLATFORMS_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func wait_frames(count: int = 5) -> void:
	for frame in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func check_ui(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Slider):
		if not Rect2(0, 0, 640, 360).encloses(node.get_global_rect()):
			overflows.append(str(node.get_global_rect()))
	for child in node.get_children():
		check_ui(child)


func shot(name: String) -> void:
	await wait_frames()
	var image := root.get_texture().get_image()
	assert(image.save_png(output.path_join(name + ".png")) == OK)
	images.append({"name": name, "width": image.get_width(), "height": image.get_height()})
	check_ui(game.menu_root)


func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	await wait_frames()
	game.foundation.complete_intro()
	game.foundation.clock.hour = 9.0
	game.foundation.clock.enabled = false
	game.set_process(false)
	game.hero.position = Vector2(776, 658)
	game.camera.position_smoothing_enabled = false
	game.camera.position = Vector2(768, 620)
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	await shot("01-pc-fullhd")
	game.platform_options.show_settings()
	await shot("02-pc-screen-controls")
	game.touch_controls.begin_edit()
	await shot("03-layout-editor")
	game.touch_controls.finish_edit(false)
	# Same shared renderer/profile used on Android; separate emulator job proves OS APK.
	game.platform_options.mobile = true
	game.platform_options.economical = true
	game.platform_options.frame_cap = 60
	game.platform_options.vsync = true
	game.platform_options.show_touch = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	game.resume()
	await shot("04-mobile-budget-play")
	var controls: Control = game.touch_controls
	controls.pointer_down(3, controls.center("stick"))
	controls.pointer_move(3, controls.center("stick") + Vector2(20, -13))
	await shot("05-analog-stick-tilted")
	controls.release_all()
	game.platform_options.show_settings()
	await shot("06-mobile-settings")
	game.foundation.show_intro()
	game.foundation.story_clock = 10000
	await shot("07-mobile-prologue")
	game.resume()
	game.begin_dialogue()
	game.type_clock = 10000
	game._process(0)
	await shot("08-mobile-dialogue")
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"images": images,
				"ui_overflows": overflows,
				"mobile_capture_is_desktop_simulation": true
			}
		)
	)
	file.close()
	game.shadows.light_depth.release_render_targets()
	await wait_frames()
	game.queue_free()
	await wait_frames()
	print("LANTERN_PLATFORMS_CAPTURE_OK 8")
	quit()
