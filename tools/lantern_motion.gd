extends SceneTree
## Real renderer motion evidence: no concept images or simulated GIF movement.
var game: Node2D
var output := ""
var frames: Array[String] = []


func _initialize() -> void:
	output = OS.get_environment("MOTION_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func wait_frames(count: int) -> void:
	for i in range(count):
		if is_instance_valid(game) and not game.is_processing() and game.mode == "play":
			game._process(1.0 / 30.0)
			game.camera.position = Vector2(385, 419)
		await process_frame


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	frames.append(label)


func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await wait_frames(4)
	game.resume()
	# Keep genuine physics/input; step visual simulation explicitly to fix the camera.
	game.set_process(false)
	game.particles_enabled = true
	game.camera.position_smoothing_enabled = false
	game.camera.limit_enabled = false
	game.camera.zoom = Vector2(1.5, 1.5)
	game.hero.position = Vector2(330, 450)
	game.hero.startled = 0.0
	game.hero.timer = 0.0
	var fox: CharacterBody2D = game.spawn_actor(Vector2(385, 450), "fox")
	var rabbit: CharacterBody2D = game.spawn_actor(Vector2(420, 453), "rabbit")
	fox.home = fox.position
	rabbit.home = rabbit.position
	await wait_frames(3)
	for i in range(48):
		if i == 0:
			Input.action_press("right")
		if i == 18:
			Input.action_release("right")
		if i == 26:
			game.hero.start_attack()
		if i == 34:
			Input.action_press("left")
		await wait_frames(3)
		# Fixed camera: motion is in the actual scene, not a pan/zoom in post.
		game.camera.position = Vector2(385, 419)
		game.camera.reset_smoothing()
		await shot("motion-%02d" % i)
	Input.action_release("left")
	# A/B isolates the live shadow layer: no other animated objects can explain differences.
	game.mode = "capture"
	for child in game.get_children():
		if child is ColorRect:
			child.hide()
	game.actors.hide()
	game.overlays.hide()
	game.particles_enabled = false
	game.hero.set_physics_process(false)
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	# Static map casters remain visible; hide moving silhouettes when their source hides.
	game.elapsed = 1.0
	await wait_frames(3)
	await shot("isolated-shadow-a")
	game.elapsed = 2.5
	await wait_frames(3)
	await shot("isolated-shadow-b")
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"images": frames, "real_render": true, "fps": 10}))
	file.close()
	print("LANTERN_MOTION_OK ", frames.size())
	game.tone_player.stop()
	game.ambience_player.stop()
	game.queue_free()
	# Return from the coroutine BEFORE quitting: release local FileAccess/script refs.
	create_timer(0.4).timeout.connect(quit)
