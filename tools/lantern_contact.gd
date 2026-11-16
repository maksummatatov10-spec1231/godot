extends SceneTree
## Real closeups and motion of the replacement animals and alpha-foot shadows.
var game: Node2D
var output := ""
var pictures: Array[String] = []


func _initialize() -> void:
	output = OS.get_environment("CONTACT_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func shot(name: String) -> void:
	game.shadows._process(0)
	game.overlays.queue_redraw()
	for wait_frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)
	pictures.append(name)


func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	for warm in range(4):
		await process_frame
	game.resume()
	game.mode = "capture"
	game.elapsed = 3.8
	game.set_process(false)
	game.camera.position_smoothing_enabled = false
	game.camera.limit_enabled = false
	var animals: Array[CharacterBody2D] = []
	var seen: Array[String] = []
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
			if not actor.species.is_empty():
				if seen.has(actor.species):
					actor.hide()
				else:
					seen.append(actor.species)
					animals.append(actor)
	game.hero.position = Vector2(720.125, 657.375)
	game.hero.facing = 0
	game.hero.animate()
	animals[0].position = Vector2(754.125, 657.375)
	animals[1].position = Vector2(790.125, 657.375)
	game.camera.position = Vector2(756.25, 648.125)
	game.camera.zoom = Vector2(3, 3)
	game.camera.force_update_scroll()
	for direction in range(4):
		for animal in animals:
			animal.facing = direction
			animal.state = "idle"
			animal.clock = 0.22
			animal.animate()
		await shot("wildlife-direction-%d" % direction)
	for gait in ["idle", "walk", "bound"]:
		for index in range(24):
			var time := float(index) / 24.0
			for animal in animals:
				animal.facing = 3
				animal.state = "idle" if gait == "idle" else "walk"
				animal.flee_time = 1.0 if gait == "bound" else 0.0
				animal.clock = time * (2.0 if gait == "idle" else 1.0)
				animal.stride_phase = fposmod(time * (2.0 if gait == "bound" else 1.0), 1.0)
				animal.animate()
			game.hero.clock = time
			game.hero.animate()
			await shot("%s-%02d" % [gait, index])
	game.camera.position = Vector2(350.125, 505.375)
	game.camera.zoom = Vector2(3, 3)
	game.camera.force_update_scroll()
	await shot("tree-contact-fractional")
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"images": pictures, "real_render": true}))
	file.close()
	game.tone_player.stop()
	game.ambience_player.stop()
	game.shadows.light_depth.release_render_targets()
	for release_frame in range(4):
		await process_frame
	game.queue_free()
	print("LANTERN_CONTACT_OK ", pictures.size())
	create_timer(0.3).timeout.connect(quit)
