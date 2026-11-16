extends SceneTree
## Dense orbit/continuity tests; no render claim from headless assertions.
const Clock = preload("res://scripts/day_clock.gd")
var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message):
		failures.append(message)


func _initialize() -> void:
	var clock := Clock.new()
	check(is_equal_approx(clock.hour, 6.25), "Default start is early morning")
	for day in [1, 8, 15, 23, 30]:
		clock.day = day
		for step in range(2401):
			clock.hour = float(step) / 100.0
			var before: Dictionary = clock.celestial()
			check(before.slope.is_finite(), "Finite shadow slope")
			check(before.slope.length() <= 2.201, "Grazing shadows are smoothly bounded")
			check(before.opacity >= 0.0 and before.opacity <= 0.435, "Bounded opacity")
			if before.sun_altitude <= 0:
				check(before.opacity <= 0.05501, "Night contrast never reaches daytime strength")
			if before.sun_altitude > 0.3:
				check(before.opacity >= 0.3799, "Daytime shadows retain strength")
			clock.hour += 0.00001
			var after: Dictionary = clock.celestial()
			check(before.slope.distance_to(after.slope) < 0.004, "No horizon angle jump")
			check(absf(before.opacity - after.opacity) < 0.0001, "No horizon contrast jump")
		clock.hour = 23.999999
		var last: Dictionary = clock.celestial()
		clock.hour = 0
		clock.day += 1
		var first: Dictionary = clock.celestial()
		check(last.slope.distance_to(first.slope) < 0.0001, "Orbit continuous across midnight")
		check(absf(last.opacity - first.opacity) < 0.0001, "Contrast continuous across midnight")
	clock.day = 1
	clock.hour = 12
	check(
		clock.celestial().slope.is_equal_approx(Vector2(0.85, 0.48)),
		"Noon retains proven reference projection"
	)
	clock.hour = 7
	var morning: Vector2 = clock.celestial().slope
	clock.hour = 17
	var evening: Vector2 = clock.celestial().slope
	check(morning.dot(evening) < 0, "Morning/evening shadows point in opposing directions")
	clock.hour = 0
	var night_power: float = clock.celestial().opacity
	clock.hour = 12
	check(
		night_power / clock.celestial().opacity < 0.15, "Night alpha under fifteen percent of day"
	)
	print("LANTERN_CELESTIAL_TEST_RESULT ", JSON.stringify({"checks": checks, "failed": failures}))
	quit(0 if failures.is_empty() else 1)
