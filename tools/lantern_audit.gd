extends SceneTree
## Whole-map zoomed, reproducible rendering; not a selection of flattering views.
var game: Node2D
var output: String
var entries: Array = []


func _initialize() -> void:
	call_deferred("run")


func snap(label: String, at: Vector2, overlay: bool = false) -> void:
	game.debug_collision = overlay
	game.overlays.queue_redraw()
	game.camera.position = at
	game.camera.reset_smoothing()
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := get_root().get_texture().get_image().save_png(output.path_join(label + ".png"))
	assert(error == OK)
	entries.append({"name": label, "world_rect": [at.x - 160, at.y - 90, 320, 180]})
	print("AUDIT ", label)


func pair(label: String, at: Vector2) -> void:
	await snap(label, at)
	await snap(label + "-collision", at, true)


func run() -> void:
	output = OS.get_environment("AUDIT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.resume()
	game.mode = "capture"
	game.ambience_player.stop()
	game.camera.limit_enabled = false
	game.camera.position_smoothing_enabled = false
	game.camera.zoom = Vector2(2, 2)
	game.particles_enabled = false
	game.hero.hide()
	# Overlap >= largest tree footprint on BOTH axes. Every object fits in one view.
	for row in range(9):
		for col in range(6):
			await pair("sector-%02d-%02d" % [row, col], Vector2(160 + col * 256, 90 + row * 128))
	var object_coverage: Array = []
	for index in range(game.map.objects.size()):
		var item: Dictionary = game.map.objects[index]
		var bounds := Rect2(item.position[0], item.position[1], item.size[0], item.size[1])
		var covered := ""
		for entry in entries:
			var r: Array = entry.world_rect
			if Rect2(r[0], r[1], r[2], r[3]).encloses(bounds):
				covered = entry.name
				break
		if covered.is_empty():
			covered = "object-%03d" % index
			await pair(covered, bounds.get_center())
		object_coverage.append({"index": index, "art": item.art, "image": covered})
	game.hero.show()
	var i := 0
	for item in game.map.objects:
		if item.art.begins_with("house"):
			game.hero.position = Vector2(item.position[0] + 24, item.position[1] + 77.1)
			game.hero.facing = 1
			await pair(
				"house-front-%02d" % i, Vector2(item.position[0] + 32, item.position[1] + 56)
			)
			i += 1
	game.hero.hide()
	for at in [Vector2(1048, 840), Vector2(1272, 840), Vector2(1048, 984), Vector2(1272, 984)]:
		await pair("fence-%d-%d" % [at.x, at.y], at)
	var road_coverage: Array = []
	for cell in game.map.paths:
		var tile := Rect2(cell[0] * 16, cell[1] * 16, 16, 16)
		var covered := ""
		for entry in entries:
			var r: Array = entry.world_rect
			if Rect2(r[0], r[1], r[2], r[3]).encloses(tile):
				covered = entry.name
				break
		assert(not covered.is_empty())
		road_coverage.append({"cell": cell, "image": covered})
	var file := FileAccess.open(output.path_join("coverage.json"), FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{"images": entries, "objects": object_coverage, "roads": road_coverage}, "\t"
		)
	)
	file.close()
	game.queue_free()
	await process_frame
	print("AUDIT_CAPTURE_OK ", entries.size())
	quit()
