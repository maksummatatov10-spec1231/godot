extends SceneTree
## Real-render acceptance tour. Separate slot, deterministic time, no live-user writes.
var game: Node2D
var output := ""
var images: Array[String] = []
var ui_overflows: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func wait_frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw


func shot(name: String) -> void:
	await wait_frames(5)
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	images.append(name)
	check_controls(game.menu_root, name)


func check_controls(node: Node, name: String) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Slider):
		if not Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(node.get_global_rect()):
			ui_overflows.append(name + ": " + str(node.get_global_rect()))
	for child in node.get_children():
		check_controls(child, name)


func view(at: Vector2) -> void:
	game.camera.position_smoothing_enabled = false
	game.camera.position = at
	game.camera.reset_smoothing()


func run() -> void:
	output = OS.get_environment("FOUNDATION_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	await wait_frames()
	game.foundation.clock.enabled = false
	game.foundation.cached_save = {}
	game.show_menu("main")
	await shot("01-first-menu")
	game.foundation.show_intro()
	for i in range(4):
		game.foundation.story_page = i
		game.foundation._render_story()
		game.foundation.story_clock = 10000
		await shot("02-story-%d" % i)
	game.foundation.complete_intro()
	game.set_process(false)
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	var phases := [
		[4.5, "predawn"],
		[6.0, "sunrise"],
		[8.5, "morning"],
		[12.0, "noon"],
		[18.0, "evening"],
		[19.7, "twilight"],
		[23.0, "night"]
	]
	for phase in phases:
		game.foundation.clock.hour = phase[0]
		game.hero.position = Vector2(764, 655)
		view(Vector2(768, 620))
		await shot("03-village-" + phase[1])
	game.foundation.lights_enabled = false
	await shot("04-night-lights-off")
	game.foundation.lights_enabled = true
	game.foundation.clock.hour = 23.0
	view(Vector2(1130, 610))
	game.hero.position = Vector2(1050, 610)
	await shot("04-lake-moon")
	view(Vector2(1136, 894))
	game.hero.position = Vector2(1145, 875)
	await shot("05-farm-night")
	view(Vector2(768, 620))
	game.hero.position = Vector2(764, 655)
	game.show_menu("pause")
	game.foundation.store.directory = "user://foundation-capture-isolated"
	game.foundation.disabled_io = false
	assert(game.foundation.save_game())
	game.foundation.disabled_io = true
	await shot("06-pause-save")
	game.foundation.clock.enabled = true
	game._open_submenu("settings", "pause")
	await shot("07-settings")
	game._open_submenu("controls", "pause")
	await shot("08-controls")
	game.foundation.cached_save = game.foundation.state()
	game.show_menu("main")
	await shot("09-continue-menu")
	game.foundation.request_new()
	await shot("10-overwrite-confirm")
	game.foundation.cancel_confirm()
	game.resume()
	game.foundation.clock.hour = 12
	game.debug_collision = true
	view(Vector2(1136, 894))
	await shot("11-farm-collisions")
	view(Vector2(1130, 610))
	await shot("12-lake-collisions")
	game.debug_collision = false
	game.show_menu("pause")
	var metadata := {
		"images": images,
		"real_render": true,
		"ui_overflows": ui_overflows,
		"size": [root.size.x, root.size.y]
	}
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("LANTERN_FOUNDATION_CAPTURE_OK ", images.size())
	game.shadows.light_depth.release_render_targets()
	await wait_frames()
	game.queue_free()
	await wait_frames()
	quit()
