extends SceneTree
## Clean screenshots of the current game, including hero, animals, particles and shadows.
var game: Node2D
var output := ""
var images: Array[String] = []


func _initialize() -> void:
	output = OS.get_environment("BEAUTY_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func wait_frames(count: int = 4) -> void:
	for i in range(count):
		await process_frame


func shot(label: String, camera_at: Vector2, hero_at: Vector2, zoom: float) -> void:
	game.hero.position = hero_at
	game.hero.facing = 0
	game.hero.state = "idle"
	game.hero.animate()
	game.camera.zoom = Vector2(zoom, zoom)
	game.camera.position = camera_at
	game.camera.reset_smoothing()
	await wait_frames()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	images.append(label)
	print("BEAUTY ", label)


func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	await wait_frames()
	game.resume()
	game.mode = "capture"
	game.elapsed = 3.8
	game.particles_enabled = true
	game.camera.position_smoothing_enabled = false
	game.camera.limit_enabled = false
	# Actual existing actors, not painted-on people. Freeze them only for the still.
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	game.hero.show()
	await shot("01-village-player-shadows", Vector2(768, 660), Vector2(776, 658), 1.2)
	await shot("02-forest-player-leaves", Vector2(350, 428), Vector2(345, 453), 1.5)
	await shot("03-farm-player-shadows", Vector2(1128, 897), Vector2(1151, 902), 1.5)
	# Stage existing wildlife actors for a readable portrait (no painted-in animals).
	for actor in game.actors.get_children():
		if actor is CharacterBody2D and not actor.species.is_empty():
			if actor.species == "fox":
				actor.position = Vector2(399, 454)
			else:
				actor.position = Vector2(440, 454)
			actor.facing = 3
			actor.state = "walk"
			actor.clock = 0.22
			actor.stride_phase = 0.22
			actor.animate()
	# Only the first fox and rabbit should occupy the portrait, not all eleven.
	var visible_species: Array[String] = []
	for actor in game.actors.get_children():
		if actor is CharacterBody2D and not actor.species.is_empty():
			if visible_species.has(actor.species):
				actor.hide()
			else:
				visible_species.append(actor.species)
	await shot("05-wildlife-player-shadows", Vector2(385, 428), Vector2(363, 454), 1.7)
	# A/B on identical camera/time/pose, proving actual raised-sprite shadow reception.
	await shot("04-received-shadow", Vector2(595, 716), Vector2(602, 754), 2.0)
	for receiver in game.shadows.light_depth.receiver_materials:
		receiver.ink.set_shader_parameter("receive_shadows", false)
	await shot("04-reception-disabled", Vector2(595, 716), Vector2(602, 754), 2.0)
	for receiver in game.shadows.light_depth.receiver_materials:
		receiver.ink.set_shader_parameter("receive_shadows", true)
	await wait_frames()
	await RenderingServer.frame_post_draw
	assert(
		(
			game.shadows.light_depth.static_view.get_texture().get_image().save_png(
				output.path_join("debug-static-depth.png")
			)
			== OK
		)
	)
	assert(
		(
			game.shadows.light_depth.moving_view.get_texture().get_image().save_png(
				output.path_join("debug-moving-depth.png")
			)
			== OK
		)
	)
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"images": images, "real_render": true, "player_visible": true})
	)
	file.close()
	print("LANTERN_BEAUTY_OK ", images.size())
	game.tone_player.stop()
	game.ambience_player.stop()
	game.shadows.light_depth.release_render_targets()
	for i in range(4):
		await process_frame
	game.queue_free()
	create_timer(0.4).timeout.connect(quit)
