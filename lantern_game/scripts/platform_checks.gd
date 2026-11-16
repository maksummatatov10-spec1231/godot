extends Node
## Shared actual-input regression driver: desktop headless and Android smoke APK.
var game: Node2D
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("PLATFORM_FAIL ", message)


func touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	get_viewport().push_input(event, true)
	Input.flush_buffered_events()


func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	get_viewport().push_input(event, true)
	Input.flush_buffered_events()


func frames(count: int = 2) -> void:
	for frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func bounds(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is BaseButton or node is Slider):
		check(
			Rect2(0, 0, 640, 360).encloses(node.get_global_rect()),
			"UI control inside logical landscape: " + node.name
		)
	for child in node.get_children():
		bounds(child)


func run(owner_world: Node2D) -> Dictionary:
	game = owner_world
	game.foundation.disabled_io = true
	game.foundation.clock.enabled = false
	game.set_process(false)
	for actor in game.actors.get_children():
		if actor is CharacterBody2D:
			actor.set_physics_process(false)
	var controls: Control = game.touch_controls
	var options: Node = game.platform_options
	options.show_touch = true
	check(controls.analog(Vector2.ONE, 30).is_zero_approx(), "Radial deadzone")
	check(
		controls.analog(Vector2(8, 6), 10).is_equal_approx(Vector2(0.8, 0.6)),
		"Continuous analog direction, not arrows"
	)
	check(controls.analog(Vector2(5, 0), 10).length() < 0.5, "Analog partial tilt scales speed")
	check(
		is_equal_approx(controls.analog(Vector2(100, 80), 10).length(), 1),
		"Outside drag clamps, never accelerates diagonally"
	)
	var invalid := ConfigFile.new()
	invalid.set_value(
		"touch", "positions", {"stick": Vector2(NAN, 4), "Z": "broken", "X": Vector2(-5, 9)}
	)
	invalid.set_value("touch", "radii", {"stick": INF, "Z": 1000, "X": -10})
	controls.load_layout(invalid)
	check(controls.positions.stick.is_finite(), "Corrupt position rejected")
	check(controls.positions.X == Vector2(0, 1), "Position clamped")
	check(controls.radii.Z == 32 and controls.radii.X == 15, "Corrupt radii bounded")
	controls.reset_layout()
	game.resume()
	game.hero.position = Vector2(768, 660)
	game.hero.timer = 0
	game.hero.state = "idle"
	game.hero.set_physics_process(true)
	await frames()
	var stick: Vector2 = controls.center("stick")
	touch(11, stick, true)
	drag(11, stick + Vector2(22, 11))
	check(
		(
			controls.stick_pointer == 11
			and controls.movement.x > controls.movement.y
			and controls.movement.y > 0
		),
		"Pointer11 owns continuous diagonal stick"
	)
	var before: Vector2 = game.hero.position
	var equipped: int = game.hero.equipped
	touch(12, controls.center("Q"), true)
	check(game.hero.equipped == (equipped + 1) % 5, "Second finger equips while moving")
	check(
		controls.stick_pointer == 11 and controls.movement.length() > 0.1,
		"Action finger cannot steal stick"
	)
	drag(99, stick - Vector2.ONE * 40)
	check(controls.movement.x > 0, "Unowned drag ignored")
	touch(12, controls.center("Q"), false)
	await frames(6)
	check(
		game.hero.position.distance_to(before) > 0.5,
		"Actual physics movement from injected screen touches"
	)
	touch(11, stick, false)
	await frames()
	check(
		controls.movement == Vector2.ZERO and game.hero.velocity == Vector2.ZERO,
		"Release stops both input and actual actor"
	)
	touch(13, stick, true)
	drag(13, stick + Vector2(controls.radii.stick * 0.58 * (0.16 + 0.05 * 0.84), 0))
	game.hero.player_step(0.016)
	check(
		game.hero.state == "walk" and game.hero.velocity.length() > 0,
		"Tiny analog tilt animates walking, not idle sliding"
	)
	var gait_before: float = game.hero.clock
	game.hero._physics_process(0.1)
	check(
		is_equal_approx(game.hero.clock - gait_before, 0.005),
		"Partial analog tilt slows gait clock continuously"
	)
	drag(13, stick + Vector2(100, 0))
	options.auto_run = false
	game.hero.player_step(0.016)
	check(is_equal_approx(game.hero.velocity.length(), 76), "Walk speed with auto-run disabled")
	options.auto_run = true
	game.hero.player_step(0.016)
	check(is_equal_approx(game.hero.velocity.length(), 112), "Auto-run speed enabled")
	touch(14, controls.center("C"), true)
	check(
		game.mode == "pause" and controls.movement == Vector2.ZERO,
		"C pauses and releases held joystick"
	)
	touch(13, stick, false)
	touch(14, controls.center("C"), false)
	game.resume()
	await frames()
	touch(15, stick, true)
	drag(15, stick + Vector2(20, 0))
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(
		controls.stick_pointer == -1 and controls.movement == Vector2.ZERO,
		"Focus loss clears all pointers"
	)
	touch(16, stick, true)
	drag(16, stick + Vector2(20, 0))
	touch(16, stick, false, true)
	check(controls.movement == Vector2.ZERO, "Canceled touch cannot stick")
	# Z/X/C use the same contextual actions as the keyboard.
	game.hero.position = game.traveller.position + Vector2(0, 25)
	game.resume()
	await frames()
	touch(20, controls.center("Z"), true)
	touch(20, controls.center("Z"), false)
	check(game.mode == "dialogue", "Z starts real dialogue")
	await frames()
	touch(21, controls.center("X"), true)
	touch(21, controls.center("X"), false)
	game._process(0)
	await frames()
	check(game.dialogue_text.visible_characters >= 30, "X reveals dialogue, not an attack")
	touch(22, controls.center("C"), true)
	touch(22, controls.center("C"), false)
	check(game.mode == "play", "C closes dialogue")
	game.show_menu("settings")
	options.show_settings()
	await frames()
	bounds(game.menu_root)
	controls.begin_edit()
	await frames()
	bounds(game.menu_root)
	var original: Vector2 = controls.positions.stick
	touch(30, controls.center("stick"), true)
	drag(30, Vector2(158, 238))
	touch(30, Vector2(158, 238), false)
	check(
		controls.positions.stick.distance_to(original) > 0.01,
		"Editor drag changes individual position"
	)
	controls.size_slider.value = 58
	check(controls.radii.stick == 58, "Editor resizes selected stick")
	controls.finish_edit(false)
	check(
		controls.positions.stick == original and controls.radii.stick == 47,
		"Cancel restores previous layout"
	)
	controls.begin_edit()
	await frames()
	touch(31, controls.center("Z"), true)
	drag(31, Vector2(540, 268))
	touch(31, Vector2(540, 268), false)
	controls.size_slider.value = 28
	controls.finish_edit(true)
	check(
		game.settings.get_value("touch", "radii", {}).get("Z") == 28,
		"Saving layout writes selected button radius"
	)
	var old_capture: bool = game.capture_running
	var old_path: String = game.settings_path
	game.capture_running = false
	game.settings_path = "user://platform-controls-validation.cfg"
	options.auto_run = true
	options.persist()
	var reread := ConfigFile.new()
	check(reread.load(game.settings_path) == OK, "Settings saved on disk")
	check(reread.get_value("platform", "auto_run", false) == true, "Auto-run persists")
	var clone := preload("res://scripts/touch_controls.gd").new()
	clone.load_layout(reread)
	check(
		clone.radii.Z == 28 and clone.positions.Z.is_equal_approx(controls.positions.Z),
		"Size and position survive disk reload"
	)
	clone.free()
	game.settings_path = old_path
	game.capture_running = old_capture
	controls.reset_layout()
	game.resume()
	game.hero.position = Vector2(776, 658)
	game.hero.timer = 0
	await frames()
	return {
		"checks": checks,
		"failed": failures,
		"android_runtime": OS.has_feature("android"),
		"renderer": RenderingServer.get_video_adapter_name()
	}
