extends Node2D
var world: Node2D


func _draw() -> void:
	var t: float = world.elapsed
	for beacon in world.beacons:
		var p: Vector2 = beacon.position
		if beacon.lit:
			for r in range(5):
				draw_circle(p - Vector2(0, 19), float(10 + r * 5), Color(1.0, 0.77, 0.35, 0.014))
	if world.particles_enabled:
		for leaf in world.leaves:
			var p := Vector2(
				fposmod(leaf.x + t * 7.0, 1536.0),
				fposmod(leaf.y + t * 3.0 + sin(t + leaf.z) * 5.0, 1152.0)
			)
			draw_set_transform(p, sin(t * 1.5 + leaf.z) * 0.8)
			draw_line(Vector2(-2, 0), Vector2(2, 0), Color(0.86, 0.69, 0.35, 0.55), 1.0)
		draw_set_transform(Vector2.ZERO)
		for fly in world.fireflies:
			var p := Vector2(fly.x + sin(t * 0.7 + fly.z) * 10, fly.y + cos(t + fly.z) * 6)
			var alpha := (sin(t * 1.2 + fly.z) + 1.0) * 0.23
			draw_circle(p, 4, Color(1, 0.94, 0.5, alpha * 0.1))
			draw_circle(p, 1, Color(1, 0.95, 0.6, alpha))
	# Water highlights are subtle and deterministic; ripples use the actual pack animation.
	if world.pulse >= 0.0:
		var radius: float = world.pulse * 115.0
		var alpha := clampf(1.0 - world.pulse / 1.2, 0, 1)
		draw_arc(world.pulse_center, radius, 0, TAU, 96, Color(1, 0.88, 0.5, alpha * 0.7), 2.0)
		draw_arc(
			world.pulse_center,
			maxf(1, radius - 5),
			0,
			TAU,
			96,
			Color(1, 0.95, 0.7, alpha * 0.3),
			1.0
		)
		for i in range(12):
			var p: Vector2 = (
				world.pulse_center
				+ Vector2.from_angle(float(i) * TAU / 12.0 + world.pulse) * radius
			)
			draw_circle(p, 1.5, Color(1, 0.92, 0.6, alpha))
	if world.mode == "play" and world.hero.position.distance_to(world.traveller.position) < 34.0:
		var p: Vector2 = world.traveller.position - Vector2(0, 27)
		draw_circle(p, 5, Color("203b34"))
		draw_circle(p, 2, Color("e8d39b"))
	if world.debug_collision:
		for shape in world.body.get_children():
			var rect := Rect2(shape.position - shape.shape.size / 2.0, shape.shape.size)
			var color := Color(1, 0.3, 0.5, 0.28)
			if shape.get_meta("kind") == "water":
				color = Color(0.1, 0.65, 1, 0.3)
			draw_rect(rect, color)
			draw_rect(rect, Color(color, 0.9), false, 0.5)
		draw_circle(world.hero.position + Vector2(0, -3), 4, Color(0.1, 1, 0.5, 0.8), false, 0.8)
