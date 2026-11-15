extends Node2D
## Small asset-free fixture for startup, native calls and rendered-frame capture.

const SPEED: float = 220.0
var player_position := Vector2(480.0, 300.0)
var native_status: String = "Native: optional libraries not built"
var smoke_mode: bool = false


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	smoke_mode = "--smoke" in arguments
	if not _check_native(arguments):
		return
	if "--test-input" in arguments and not _test_input_action():
		return
	queue_redraw()
	if smoke_mode:
		var before: Vector2 = player_position
		_move_player(Vector2.RIGHT, 0.25)
		if not is_equal_approx(player_position.x - before.x, SPEED * 0.25):
			_fail("Movement smoke test failed")
			return
		player_position = before
		if _capture_path(arguments).is_empty():
			print("SMOKE_OK")
			get_tree().quit(0)
			return
	var capture_path: String = _capture_path(arguments)
	if not capture_path.is_empty():
		await _capture_frame(capture_path)


func _test_input_action() -> bool:
	# Exercise the Input action path deterministically, not a physical OS keyboard.
	var before: Vector2 = player_position
	Input.action_press(&"ui_right")
	var previous_mode: bool = smoke_mode
	smoke_mode = false
	_physics_process(0.25)
	smoke_mode = previous_mode
	Input.action_release(&"ui_right")
	if not is_equal_approx(player_position.x - before.x, SPEED * 0.25):
		_fail("Input action did not move the player by the expected distance")
		return false
	print("INPUT_OK x=", player_position.x)
	return true


func _check_native(arguments: PackedStringArray) -> bool:
	var statuses: PackedStringArray = []
	for language: String in ["cpp", "rust"]:
		var native_class: StringName = &"CppProbe" if language == "cpp" else &"RustProbe"
		if not ClassDB.class_exists(native_class):
			if "--require-%s" % language in arguments:
				_fail("%s not registered; build the extension first" % native_class)
				return false
			continue
		var probe: Object = ClassDB.instantiate(native_class)
		if probe == null:
			_fail("Cannot instantiate %s" % native_class)
			return false
		for values: Array in [
			[20, 22, 42], [2147483647, 1, 2147483648], [-2147483648, -1, -2147483649]
		]:
			if probe.call(&"add", values[0], values[1]) != values[2]:
				_fail("%s returned an incorrect native result" % native_class)
				return false
		statuses.append("%s: GDExtension calls passed" % ("C++" if language == "cpp" else "Rust"))
		print("NATIVE_OK ", native_class, " (normal + int32 boundaries)")
	if not statuses.is_empty():
		native_status = " | ".join(statuses)
	return true


func _capture_frame(capture_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Screenshot requires a real rendering driver, not --headless")
		return
	# Wait for a completed render, not just a process/physics tick.
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Rendered image is empty")
		return
	var result: Error = image.save_png(capture_path)
	if result != OK:
		_fail("Cannot save screenshot: %s" % error_string(result))
		return
	print("CAPTURE_OK ", capture_path)
	if smoke_mode:
		print("SMOKE_OK")
		get_tree().quit(0)


func _physics_process(delta: float) -> void:
	if smoke_mode:
		return
	_move_player(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"), delta)
	queue_redraw()


func _move_player(direction: Vector2, delta: float) -> void:
	player_position += direction * SPEED * delta
	player_position = player_position.clamp(Vector2(24, 200), Vector2(936, 516))


func _draw() -> void:
	for x: int in range(0, 961, 40):
		draw_line(Vector2(x, 180), Vector2(x, 540), Color(0.10, 0.15, 0.22))
	for y: int in range(180, 541, 40):
		draw_line(Vector2(0, y), Vector2(960, y), Color(0.10, 0.15, 0.22))
	var font: Font = ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(36, 58),
		"GODOT DEVELOPMENT LAB",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		30,
		Color(0.4, 0.85, 1.0)
	)
	draw_string(
		font,
		Vector2(36, 100),
		"Arrow keys: move / deterministic smoke fixture",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20
	)
	draw_string(font, Vector2(36, 138), native_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_circle(player_position, 18.0, Color(0.35, 0.95, 0.7))
	draw_circle(player_position, 24.0, Color(0.35, 0.95, 0.7, 0.3), false, 2.0)


func _capture_path(arguments: PackedStringArray) -> String:
	for argument: String in arguments:
		if argument.begins_with("--capture="):
			return argument.trim_prefix("--capture=")
	return ""


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
