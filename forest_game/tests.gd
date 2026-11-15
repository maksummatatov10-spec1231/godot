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
	player.set_first_person(false)
	check(
		player.camera.cull_mask == 3 and not player.viewmodel.visible,
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
	world.toggle_quality()
	check(
		not world.environment.volumetric_fog_enabled,
		"balanced graphics toggle disables expensive fog"
	)
	world.toggle_quality()
	check(world.environment.volumetric_fog_enabled, "ultra profile restores fog")
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
	quit(0 if failures.is_empty() else 1)
