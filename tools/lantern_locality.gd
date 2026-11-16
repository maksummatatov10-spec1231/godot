extends SceneTree


## Compare camera-culling to a full-world reference at identical time and pose.
class ReferenceWorld:
	extends Node2D
	var shadows: Node2D

	func world_view_rect() -> Rect2:
		return Rect2(-110, -110, 1640, 1260)


var game: Node2D
var output := ""
var captures: Array[String] = []


func _initialize() -> void:
	output = OS.get_environment("LOCALITY_DIR")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")


func shot(name: String) -> void:
	game.overlays.queue_redraw()
	game.shadows.queue_redraw()
	for wait_frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK)


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
	game.shadows.set_process(false)
	game.camera.position_smoothing_enabled = false
	game.camera.limit_enabled = false
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	var reference := ReferenceWorld.new()
	reference.shadows = game.shadows
	var depth: Node = game.shadows.light_depth
	var views := [
		["village", Vector2(768, 660), 1.2],
		["forest-edge", Vector2(350, 428), 1.5],
		["farm", Vector2(1128, 897), 1.5],
		["facade", Vector2(595, 716), 2.0],
		["crop-boundary-left", Vector2(672, 640), 1.0],
		["crop-boundary-right", Vector2(673, 641), 1.0],
	]
	for view in views:
		var name: String = view[0]
		game.camera.position = view[1]
		game.camera.zoom = Vector2.ONE * view[2]
		game.camera.force_update_scroll()
		game.hero.position = view[1] + Vector2(0, 12)
		game.hero.animate()
		depth.world = game
		game.shadows.visibility_rect = Rect2()
		game.shadows._process(0)
		await shot(name + "-local")
		# Full-world light coordinates, all ground silhouettes and particles. No
		# temporal/pose difference: any missing on-screen caster causes a pixel diff.
		depth.world = reference
		depth.update(game.shadows.casters, game.elapsed)
		for entry in game.shadows.casters:
			game.shadows.sync(entry)
		game.shadows.visibility_rect = Rect2(-128, -128, 1792, 1408)
		game.shadows.visible_leaves.assign(game.leaves)
		game.shadows.visible_fireflies.assign(game.fireflies)
		await shot(name + "-reference")
		captures.append(name)
		print("LOCALITY ", name)
	reference.free()
	depth.world = game
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"pairs": captures}))
	file.close()
	game.tone_player.stop()
	game.ambience_player.stop()
	depth.release_render_targets()
	for release_frame in range(4):
		await process_frame
	game.queue_free()
	print("LANTERN_LOCALITY_OK ", captures.size())
	create_timer(0.2).timeout.connect(quit)
