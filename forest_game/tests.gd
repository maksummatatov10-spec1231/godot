extends SceneTree
## Actual fixed-tick gameplay checks. Camera/animation renders are a separate suite.
var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	print("CHECK ", "PASS " if condition else "FAIL ", message)
	if not condition:
		failures.append(message)


func ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func run() -> void:
	world = load("res://world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	player = world.player
	await ticks(40)
	check(player.is_on_floor(), "capsule rests on the actual triangulated forest ground")
	check(player.animator.get_animation_list().size() >= 14, "14 real skeletal clips imported")
	var start := player.position
	Input.action_press("forward")
	await ticks(60)
	Input.action_release("forward")
	await ticks(20)
	check(player.position.z < start.z - 2.0, "forward movement uses velocity and move_and_slide")
	for action in ["back", "left", "right"]:
		start = player.position
		Input.action_press(action)
		await ticks(45)
		Input.action_release(action)
		await ticks(12)
		check(player.position.distance_to(start) > 1.0, "directional walking: " + action)
	player.set_first_person(true)
	check(
		player.camera.cull_mask == 1 and player.viewmodel.visible,
		"first person shows viewmodel, hides head/body clipping"
	)
	var fps_skeleton: Skeleton3D = player.viewmodel.find_children("*", "Skeleton3D", true, false)[0]
	var modifier: SkeletonModifier3D = (
		fps_skeleton.find_children("*", "SkeletonModifier3D", false, false)[0]
	)
	modifier.call("_process_modification")
	var wrist := fps_skeleton.get_bone_global_pose(fps_skeleton.find_bone("hand_r")).origin
	check(wrist.z < -0.4 and wrist.y < 0.0, "FPS wrist/grip is in front of and below lens")
	check(player.legs.visible, "first person retains animated lower body")
	var all_shadow_only := true
	for mesh in player.body_meshes:
		all_shadow_only = (
			all_shadow_only
			and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		)
	check(all_shadow_only, "first person retains complete body and weapon shadow")
	player.position = Vector3(0, 0.05, 7)
	player.reset_physics_interpolation()
	player.velocity = Vector3.ZERO
	Input.action_press("forward")
	Input.action_press("sprint")
	await ticks(30)
	check(
		Vector2(player.velocity.x, player.velocity.z).length() > 5.2,
		"Shift sprint works in first person"
	)
	Input.action_release("forward")
	Input.action_release("sprint")
	await ticks(20)
	player.set_first_person(false)
	check(
		player.camera.cull_mask == 1 and not player.viewmodel.visible and not player.legs.visible,
		"third person restores animated full body"
	)
	player.position = Vector3(0, 0.05, 1)
	player.velocity = Vector3.ZERO
	await ticks(20)
	Input.action_press("jump")
	await ticks(10)
	Input.action_release("jump")
	check(player.position.y > 0.45 and not player.is_on_floor(), "jump impulse leaves ground")
	await ticks(90)
	check(player.is_on_floor(), "gravity and floor snap land without falling through terrain")
	# Combat is tested against an actual collidable ward, not a mocked damage call.
	player.position = Vector3(0, 0.05, -0.1)
	player.yaw = 0
	player.velocity = Vector3.ZERO
	await ticks(20)
	var ward: Node3D = world.targets[0]
	player.attack()
	await ticks(55)
	check(
		player.damage_events == 1 and ward.health == 66,
		"sword applies one 34-damage contact in range/cone"
	)
	player.position = Vector3(0, 0.05, 4.0)
	player.action_timer = 0.0
	player.cast_magic()
	var cooldown: float = player.magic_cooldown
	player.cast_magic()
	check(
		is_equal_approx(player.magic_cooldown, cooldown),
		"magic cannot bypass cooldown by repeated calls"
	)
	await ticks(100)
	check(
		player.magic_hits >= 1 and ward.health <= 1,
		"asset VFX projectile swept collision deals magic damage"
	)
	await ticks(180)
	check(ward.health == 100, "shattered training ward reforms for repeatable testing")
	player.position = Vector3(0, 0.05, 5)
	player.velocity = Vector3.ZERO
	await ticks(12)
	var diagonal_start := player.position
	Input.action_press("forward")
	Input.action_press("right")
	await ticks(60)
	Input.action_release("forward")
	Input.action_release("right")
	var diagonal_distance := player.position.distance_to(diagonal_start)
	check(
		diagonal_distance > 2.4 and diagonal_distance < 3.5,
		"diagonal movement is normalized, not sqrt(2) faster"
	)
	player.position = Vector3(0, 0.05, 7)
	player.velocity = Vector3.ZERO
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 2, 0.2)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector3(0.4, 1.7, 9)
	await ticks(12)
	check(
		player.camera.global_position.distance_to(player.global_position + Vector3.UP * 1.55) < 3,
		"camera retracts before collidable obstacle"
	)
	wall.queue_free()
	await ticks(6)
	world.toggle_quality()
	check(
		not world.environment.volumetric_fog_enabled,
		"balanced graphics toggle disables expensive fog"
	)
	world.toggle_quality()
	check(world.environment.volumetric_fog_enabled, "ultra profile restores fog")
	check(
		world.grass_batches.size() > 20, "grass is spatially chunked, not one whole-world MultiMesh"
	)
	world.set_grass_shadows(true)
	check(
		world.grass_batches[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON,
		"grass shadows enabled"
	)
	world.set_grass_shadows(false)
	check(
		world.grass_batches[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"grass shadow option applies"
	)
	world.set_grass_shadows(true)
	world.menu.options.birds = false
	world.menu.apply_options()
	check(
		world.birds.volume_db <= -79 and world.wind.volume_db > -79,
		"birds can be muted independently of wind"
	)
	world.menu.options.birds = true
	world.menu.apply_options()
	var initial_count: int = world.effects.get_child_count()
	for i in range(12):
		var effect: Node3D = world.effects.acquire("cast", Vector3(0, 1, 0), 0.42)
		world.effects.release(effect)
	check(
		world.effects.get_child_count() == initial_count,
		"repeated magic reuses fixed-size VFX pool"
	)
	check(player.trail.mesh.get_aabb().size.y > 0.03, "sword trail has physical 3D thickness")
	world.menu.started = true
	world.menu.ready_to_play = true
	world.menu.pause()
	check(paused and world.menu.visible, "Escape menu pauses actual world simulation")
	world.menu.show_graphics()
	check(world.menu.screen == "graphics", "graphics settings screen opens while paused")
	world.menu.show_audio()
	check(world.menu.screen == "audio", "audio settings screen opens while paused")
	world.menu.resume()
	check(not paused and not world.menu.visible, "resume returns to gameplay")
	print(
		"FOREST_TEST_RESULT ",
		JSON.stringify(
			{
				"failed": failures,
				"sword_hits": player.damage_events,
				"magic_hits": player.magic_hits
			}
		)
	)
	if failures.is_empty():
		print("FOREST_TEST_OK")
	await world.stop_audio()
	quit(0 if failures.is_empty() else 1)
