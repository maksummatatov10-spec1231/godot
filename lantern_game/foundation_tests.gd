extends SceneTree
## Isolated persistence/clock/UI tests. Never writes the live journey slot.
const Store = preload("res://scripts/save_store.gd")
const Clock = preload("res://scripts/day_clock.gd")
const TEST_DIR = "user://foundation-validation"
var checks := 0
var failures: Array[String] = []
var game: Node2D


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)


func _initialize() -> void:
	call_deferred("run")


func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func run() -> void:
	var clock := Clock.new()
	clock.hour = 23.9
	clock.cycle_minutes = 24
	clock.advance(12)
	check(clock.day == 2 and is_equal_approx(clock.hour, 0.1), "Midnight wraps exactly once")
	clock.enabled = false
	clock.advance(600)
	check(is_equal_approx(clock.hour, 0.1), "Disabled time freezes")
	for hour in [0.0, 4.0, 5.5, 7.5, 11.0, 15.0, 18.0, 19.5, 21.0, 23.999]:
		clock.hour = hour
		var color := clock.tint()
		clock.hour = fposmod(hour + 0.001, 24)
		check(
			color.is_equal_approx(clock.tint()) or color.r - clock.tint().r < 0.002,
			"Smooth color boundary"
		)
		check(not clock.period().is_empty(), "Named time period")
	game = load("res://main.tscn").instantiate()
	game.capture_running = true
	root.add_child(game)
	await process_frame
	await physics_frame
	var foundation: Node = game.foundation
	foundation.store.directory = TEST_DIR
	game.settings_path = TEST_DIR.path_join("settings.cfg")
	foundation.disabled_io = false
	var writer := false
	var reader := false
	for arg in OS.get_cmdline_user_args():
		writer = writer or arg == "--persistence-write"
		reader = reader or arg == "--persistence-read"
	if reader:
		var restored_settings := ConfigFile.new()
		check(
			restored_settings.load(game.settings_path) == OK, "Settings survive a separate process"
		)
		check(
			restored_settings.get_value("save", "interval", 0) == 300,
			"Autosave preference survives restart"
		)
		var persisted: Dictionary = foundation.store.load_game()
		check(not persisted.is_empty(), "New engine process reads previous process save")
		if not persisted.is_empty():
			foundation.apply_state(persisted)
			check(
				game.hero.equipped == 3 and foundation.clock.day == 4,
				"Cross-process equipment and day"
			)
			check(game.beacons[2].lit and foundation.intro_done, "Cross-process world/story state")
		finish()
		return
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(TEST_DIR.path_join("journey.json" + suffix))
	check(not foundation.store.exists(), "Clean first run has no Continue")
	press("interact")
	await process_frame
	check(game.mode == "intro", "First-play enters story")
	press("cancel")
	await process_frame
	check(foundation.story_text.visible_characters > 30, "X reveals text")
	press("interact")
	check(foundation.story_page == 1, "Z advances story after reveal")
	press("pause")
	check(game.mode == "confirm", "Escape asks before skipping")
	foundation.cancel_confirm()
	check(game.mode == "intro", "Cancel skip returns to story")
	foundation.complete_intro()
	check(game.mode == "play" and foundation.store.exists(), "Story completion starts and saves")
	check(is_equal_approx(foundation.clock.hour, Clock.START_HOUR), "New journey starts at 06:15")
	game.hero.equipped = 3
	game.hero.facing = 2
	foundation.clock.day = 4
	foundation.clock.hour = 21.25
	game.beacons[2].lit = true
	check(foundation.save_game(), "Manual save succeeds")
	var data: Dictionary = foundation.store.load_game()
	check(data.equipped == 3 and data.facing == 2, "Equipment and direction roundtrip")
	check(data.beacons[2] and data.intro_done, "Beacon and prologue roundtrip")
	check(is_equal_approx(data.hour, 21.25) and data.day == 4, "Clock roundtrip")
	foundation.clock.enabled = true
	game.show_menu("pause")
	var old_hour: float = foundation.clock.hour
	foundation._process(10)
	check(foundation.clock.hour == old_hour, "Pause freezes day and autosave timer")
	game.resume()
	foundation.autosave_seconds = 60
	foundation.autosave_clock = 59.9
	foundation._process(0.2)
	check(foundation.autosave_clock == 0, "Timed autosave fires during play")
	foundation.autosave_seconds = 0
	foundation.autosave_clock = 100
	foundation._process(1)
	check(foundation.autosave_clock == 100, "Disabled autosave stays disabled")
	game.show_menu("main")
	check(
		game.get_viewport().gui_get_focus_owner().text == "Продолжить",
		"Saved slot offers Continue first"
	)
	foundation.request_new()
	check(game.mode == "confirm", "New game protects existing progress")
	foundation.cancel_confirm()
	check(game.mode == "main", "New game cancellation preserves slot")
	var solid: Array = game.map.solids[0].rect
	var blocked := Vector2(solid[0] + solid[2] * 0.5, solid[1] + solid[3] * 0.5 + 3)
	check(
		foundation.safe_position(blocked) == Vector2(776, 658),
		"Solid-position saves recover to safe spawn"
	)
	var wall_contact := Vector2(480, 399.1)
	check(
		foundation.safe_position(wall_contact) == wall_contact,
		"Valid four-pixel wall contact is preserved"
	)
	var corner_clear := Vector2(512, 398.1)
	check(
		foundation.safe_position(corner_clear) == corner_clear,
		"Circle-clear wall corners are preserved"
	)
	var beside_wall: Dictionary = data.duplicate(true)
	beside_wall.x = wall_contact.x
	beside_wall.y = wall_contact.y
	foundation.apply_state(beside_wall)
	check(
		game.hero.position == wall_contact, "Continue does not teleport a legal wall-adjacent save"
	)
	var bad: Dictionary = data.duplicate(true)
	bad.x = -10
	check(not foundation.store.save(bad), "Out-of-bounds state rejected")
	bad = data.duplicate(true)
	bad.hour = INF
	check(not foundation.store.save(bad), "Nonfinite state rejected")
	bad = data.duplicate(true)
	bad.beacons = [false]
	check(not foundation.store.save(bad), "Incorrect beacon payload rejected")
	# Save twice to establish a known-good backup, then corrupt only the primary.
	check(foundation.store.save(data) and foundation.store.save(data), "Backup established")
	var file := FileAccess.open(TEST_DIR.path_join("journey.json"), FileAccess.WRITE)
	file.store_string("{interrupted write")
	file.close()
	check(
		not foundation.store.load_game().is_empty() and foundation.store.recovered,
		"Truncated primary recovers backup"
	)
	check(foundation.store.save(data), "Can save after backup recovery")
	var impossible := Store.new()
	impossible.directory = TEST_DIR.path_join("journey.json/invalid")
	check(
		not impossible.save(data) and not impossible.last_error.is_empty(),
		"Disk/path errors are reported"
	)
	foundation.autosave_seconds = 300
	foundation.clock.cycle_minutes = 12
	game.capture_running = false
	foundation.persist_options()
	game.capture_running = true
	var options := ConfigFile.new()
	check(options.load(game.settings_path) == OK, "Options written to isolated user data")
	check(options.get_value("time", "minutes", 0) == 12, "Day-cycle option persisted")
	if writer:
		check(foundation.store.save(data), "Write fixture for independent process")
	finish()


func finish() -> void:
	print("FOUNDATION_TEST_RESULT ", JSON.stringify({"checks": checks, "failed": failures}))
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
