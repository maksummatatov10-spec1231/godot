extends SceneTree
## Frozen-pose real renders: only clock changes; checks GPU reprojection/cache reuse.
var game: Node2D
var output := ""
var samples: Array = []


func _initialize() -> void:
	output = OS.get_environment("CELESTIAL_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func shot(name: String) -> void:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)


func run() -> void:
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	for frame in range(5):
		await process_frame
	game.resume()
	game.set_process(false)
	game.shadows.set_process(false)
	game.foundation.clock.enabled = false
	game.elapsed = 3.8
	game.camera.position_smoothing_enabled = false
	game.camera.position = Vector2(768, 620)
	game.camera.zoom = Vector2.ONE * 1.2
	game.camera.force_update_scroll()
	game.hero.position = Vector2(776, 658)
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
			if actor != game.hero:
				actor.hide()
	game.shadows._process(0)
	var depth: Node = game.shadows.light_depth
	var rebuilds: int = depth.mesh_rebuilds
	var poses: int = depth.pose_builds
	for hour in [0.0, 4.5, 5.99, 6.01, 6.25, 8.0, 10.0, 12.0, 14.0, 16.0, 17.99, 18.01, 20.0, 23.0]:
		game.foundation.clock.hour = hour
		game.shadows._process(0)
		var light: Dictionary = game.foundation.clock.celestial()
		var name := "orbit-%04d" % int(hour * 100)
		await shot(name)
		samples.append(
			{
				"image": name,
				"hour": hour,
				"slope": [light.slope.x, light.slope.y],
				"opacity": light.opacity
			}
		)
		if hour == 0.0 or hour == 12.0:
			RenderingServer.global_shader_parameter_set(
				"shadow_light", Vector4(light.slope.x, light.slope.y, 0, 0)
			)
			await shot(name + "-no-shadows")
	assert(depth.mesh_rebuilds == rebuilds, "Clock must not rebuild frozen moving geometry")
	assert(depth.pose_builds == poses, "Clock must not regenerate pose templates")
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"samples": samples,
				"clock_pose_rebuilds": depth.pose_builds - poses,
				"clock_mesh_rebuilds": depth.mesh_rebuilds - rebuilds
			}
		)
	)
	file.close()
	depth.release_render_targets()
	for frame in range(4):
		await process_frame
	game.queue_free()
	for frame in range(4):
		await process_frame
	print("LANTERN_CELESTIAL_CAPTURE_OK 16")
	quit()
