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
	var wrist: Vector3 = (
		player.camera.global_transform.affine_inverse()
		* fps_skeleton.global_transform
		* fps_skeleton.get_bone_global_pose(fps_skeleton.find_bone("hand_r")).origin
	)
	check(wrist.z < -0.15 and wrist.y < 0.15, "FPS wrist/grip is in front of and below lens")
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
	var blade_directions: Array[Vector3] = []
	var parity := true
	for clip in [
		"Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Walk", "Jump", "Jump_Land"
	]:
		player.current_clip = ""
		player.play_clip(clip)
		player.animator.play(clip, 0)
		player.animator.seek(0.3, true)
		player.advance_animation(0)
		var bone: int = player.skeleton.find_bone("hand_r")
		var original: Transform3D = player.arm_skeleton.get_bone_global_pose(bone)
		modifier.call("_process_modification")
		var adapted: Transform3D = player.arm_skeleton.get_bone_global_pose(bone)
		parity = (
			parity
			and (
				original.basis.orthonormalized().get_rotation_quaternion().angle_to(
					adapted.basis.orthonormalized().get_rotation_quaternion()
				)
				< 0.002
			)
		)
		var finger: int = player.skeleton.find_bone("index_02_r")
		parity = (
			parity
			and player.skeleton.get_bone_pose(finger).is_equal_approx(
				player.arm_skeleton.get_bone_pose(finger)
			)
		)
		parity = (
			parity
			and (
				absf(
					(
						player.animator.current_animation_position
						- player.view_animator.current_animation_position
					)
				)
				< 0.001
			)
		)
		if clip.begins_with("Sword_Regular"):
			blade_directions.append(adapted.basis.z.normalized())
	check(parity, "FPS preserves original wrist rotation, finger channels and exact clip phase")
	check(
		(
			blade_directions[0].distance_to(blade_directions[1]) > 0.2
			and blade_directions[1].distance_to(blade_directions[2]) > 0.2
		),
		"FPS A/B/C use three distinct source blade directions, not one generic swing"
	)
	check(
		player.world_sword.transform.is_equal_approx(player.view_sword.transform),
		"both views share exactly the calibrated palm socket and weapon scale"
	)
	# sword_C handle lies on local +Y; the guard starts around Y=0.24.
	# Match the measured closed-finger pocket, not the wrist origin/pommel.
	var pocket := Vector3(-0.03, 0.104, 0)
	var handle_center: Vector3 = player.view_sword.transform * Vector3(0, 0.154, 0)
	var guard_edge: Vector3 = player.view_sword.transform * Vector3(0, 0.24, 0)
	check(
		handle_center.distance_to(pocket) < 0.015 and guard_edge.z > 0.038,
		"handle crosses closed finger pocket and guard clears the index knuckle"
	)
	player.current_clip = ""
	player.play_clip("Sword_Idle")
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
	player.position = Vector3(0, 0.05, 7)
	player.reset_physics_interpolation()
	player.pitch = -0.09
	player.camera_initialized = false
	var orbit_error := 0.0
	for i in range(144):
		player.yaw = float(i) * 0.006
		player.update_camera(1.0 / 144.0, 0)
		var pivot := player.get_global_transform_interpolated().origin + Vector3.UP * 1.55
		var ideal: Vector3 = (
			pivot + player.camera.basis * Vector3(0.5, 0.25, player.camera_distance)
		)
		orbit_error = maxf(orbit_error, player.camera.global_position.distance_to(ideal))
	check(orbit_error < 0.01, "144 Hz camera orbit stays centred without world-position lag")
	player.yaw = 0
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
	var benchmark_script := load("res://scripts/benchmark.gd")
	var benchmark := Node.new()
	benchmark.set_script(benchmark_script)
	world.add_child(benchmark)
	benchmark.world = world
	benchmark.frames.assign([10.0, 20.0, 30.0])
	benchmark.path = "user://self_test_benchmark.json"
	benchmark.finish()
	var stats: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("user://self_test_benchmark.json")
	)
	check(
		is_equal_approx(float(stats.average_fps), 50.0) and float(stats.p99_ms) == 30.0,
		"benchmark computes delivered-frame average and p99 correctly"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://self_test_benchmark.json"))
	world.menu.resume()
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
