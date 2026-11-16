extends Node
## Only the separate android_smoke export calls this driver. Never runs in player APK.
var game: Node2D
var ready_for_os_input := false
var initial_position := Vector2.ZERO
var observed_os_motion := false
var last_mode := ""


func run(world: Node2D) -> void:
	game = world
	await get_tree().create_timer(1.0).timeout
	var driver := preload("res://scripts/platform_checks.gd").new()
	add_child(driver)
	var result: Dictionary = await driver.run(world)
	result["mobile_profile"] = world.platform_options.mobile
	result["viewport_render"] = (
		get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT
	)
	result["landscape"] = DisplayServer.window_get_size().x > DisplayServer.window_get_size().y
	if not result.mobile_profile or not result.viewport_render or not result.landscape:
		result.failed.append("Android landscape/economical profile not active")
	world.foundation.disabled_io = false
	world.foundation.complete_intro()
	world.set_process(true)
	initial_position = world.hero.position
	await get_tree().process_frame
	var stick: Vector2 = (
		get_viewport().get_screen_transform() * world.touch_controls.center("stick")
	)
	result["stick_screen"] = [stick.x, stick.y]
	result["screen_travel"] = (
		world.touch_controls.radii.stick
		* get_viewport().get_screen_transform().get_scale().x
		* 0.58
	)
	print("LANTERN_ANDROID_SMOKE_RESULT ", JSON.stringify(result))
	print("LANTERN_ANDROID_SMOKE_OK" if result.failed.is_empty() else "LANTERN_ANDROID_SMOKE_FAIL")
	ready_for_os_input = result.failed.is_empty()


func _process(_delta: float) -> void:
	if not ready_for_os_input:
		return
	if last_mode != game.mode:
		last_mode = game.mode
		print("LANTERN_ANDROID_MODE ", last_mode)
	if not observed_os_motion and game.touch_controls.movement.length() > 0.1:
		if game.hero.position.distance_to(initial_position) > 1:
			observed_os_motion = true
			print("LANTERN_ANDROID_OS_TOUCH_OK")


func resumed() -> void:
	if not ready_for_os_input or not observed_os_motion:
		return
	await get_tree().process_frame
	var saved: Dictionary = game.foundation.store.load_game()
	if (
		not saved.is_empty()
		and game.mode == "pause"
		and game.touch_controls.movement == Vector2.ZERO
	):
		if Vector2(saved.x, saved.y).distance_to(game.hero.position) < 0.1:
			print("LANTERN_ANDROID_RESUME_SAVE_OK")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and ready_for_os_input:
		call_deferred("resumed")
