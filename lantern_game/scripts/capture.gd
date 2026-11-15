extends Node
var game: Node2D
var output := ""
var images: Array[String] = []


func shot(label: String) -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := game.get_viewport().get_texture().get_image().save_png(
		output.path_join(label + ".png")
	)
	assert(error == OK)
	images.append(label)
	print("CAPTURE ", label)


func view(at: Vector2) -> void:
	game.hero.position = at
	game.hero.velocity = Vector2.ZERO
	game.camera.position = at
	game.camera.reset_smoothing()


func run(target: Node2D, directory: String) -> void:
	game = target
	output = directory
	DirAccess.make_dir_recursive_absolute(output)
	await shot("01-main-menu")
	game.resume()
	game.camera.limit_enabled = false
	game.camera.zoom = Vector2(0.3, 0.3)
	view(Vector2(768, 576))
	game.mode = "capture"
	await shot("00-map-overview")
	game.debug_collision = true
	await shot("00-map-collisions")
	game.debug_collision = false
	game.camera.limit_enabled = true
	game.camera.zoom = Vector2.ONE
	game.mode = "play"
	view(Vector2(776, 658))
	await shot("02-village")
	game.debug_collision = true
	await shot("03-village-collisions")
	game.debug_collision = false
	game.hero.position = game.traveller.position + Vector2(0, 23)
	game.begin_dialogue()
	game.type_clock = 999.0
	await shot("04-traveller")
	game.mode = "play"
	game.dialog_root.hide()
	for place in ["lake", "farm", "forest"]:
		var at: Array = game.map.views[place]
		view(Vector2(at[0], at[1]))
		if place == "lake":
			game.hero.position = Vector2(1074, 610)
		elif place == "forest":
			game.hero.position = Vector2(280, 504)
		game.mode = "capture"
		await shot("05-" + place)
		game.debug_collision = true
		await shot("06-" + place + "-collisions")
		game.debug_collision = false
	game.mode = "play"
	view(Vector2(776, 658))
	game.use_ability()
	game.pulse = 0.55
	game.mode = "capture"
	await shot("07-lantern-ability")
	game.pulse = -1.0
	game.hero.state = "attack"
	game.hero.timer = 0.12
	game.hero.animate()
	await shot("08-sword")
	game.hero.state = "idle"
	game.hero.timer = 0.0
	game.hero.equipped = 1
	game.hero.update_tool()
	game.hero.animate()
	await shot("09-axe")
	var fox: CharacterBody2D = game.spawn_actor(game.hero.position + Vector2(16, 0), "fox")
	game.mode = "play"
	fox.animal_step(0.016)
	game.hero.surprise(fox.position)
	game.mode = "capture"
	await shot("10-wildlife-surprise")
	game.show_menu("pause")
	await shot("11-pause")
	game.returning_to = "pause"
	game.show_menu("settings")
	await shot("12-settings")
	game.show_menu("controls")
	await shot("13-controls")
	# An atlas of real player animations, not substituted concept artwork.
	game.resume()
	view(Vector2(776, 658))
	game.mode = "capture"
	for facing in range(4):
		game.hero.facing = facing
		game.hero.state = "walk"
		game.hero.clock = 0.22
		game.hero.animate()
		await shot("14-walk-" + str(facing))
	game.hero.equipped = 3
	game.hero.update_tool()
	game.hero.state = "attack"
	game.hero.timer = 0.12
	game.hero.animate()
	await shot("15-net")
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"images": images,
				"renderer": RenderingServer.get_video_adapter_name(),
				"real_render": true
			},
			"\t"
		)
	)
	file.close()
	print("LANTERN_CAPTURE_OK ", images.size())
