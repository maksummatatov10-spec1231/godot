extends Node2D
var world: Node2D
var last_state: Array = []


func _process(_delta: float) -> void:
	# Retain CanvasItem draw commands while paused. Time, camera, toggles and
	# interaction changes invalidate them; static menus do not rebuild particles.
	var state := [
		world.elapsed,
		world.foundation.clock.hour,
		world.world_view_rect(),
		world.particles_enabled,
		world.debug_collision,
		world.pulse,
		world.mode,
		world.hero.position
	]
	for beacon in world.beacons:
		state.append(beacon.lit)
	if state != last_state:
		queue_redraw()
		last_state = state


func _draw() -> void:
	var t: float = world.elapsed
	var view: Rect2 = world.world_view_rect().grow(8.0)
	for beacon in world.beacons:
		var p: Vector2 = beacon.position
		if not view.grow(32).has_point(p):
			continue
		if beacon.lit:
			for r in range(5):
				draw_circle(p - Vector2(0, 19), float(10 + r * 5), Color(1.0, 0.77, 0.35, 0.014))
	if world.particles_enabled:
		for leaf in world.shadows.visible_leaves:
			var sample: Vector3 = world.leaf_sample(leaf)
			var phase := fposmod(t + leaf.z, 12.0) / 12.0
			var alpha := smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.82, 1.0, phase))
			var turn := sin(t * 3.6 + leaf.z)
			var p := Vector2(sample.x, sample.y)
			if not view.has_point(p):
				continue
			draw_set_transform(p, sin(t * 1.8 + leaf.z), Vector2(0.4 + absf(turn) * 0.6, 1))
			var tint := Color("ebc66e") if int(leaf.z) % 3 else Color("b9ce70")
			tint.a = alpha * 0.9
			draw_colored_polygon(
				PackedVector2Array(
					[Vector2(-2.5, 0), Vector2(0, -1.5), Vector2(2.5, 0), Vector2(0, 1.5)]
				),
				tint
			)
			draw_line(Vector2(-1.5, 0), Vector2(2, 0), Color(0.42, 0.34, 0.16, alpha * 0.65), 0.6)
		draw_set_transform(Vector2.ZERO)
		for fly in world.shadows.visible_fireflies:
			var p := Vector2(fly.x + sin(t * 0.7 + fly.z) * 10, fly.y + cos(t + fly.z) * 6)
			if not view.has_point(p):
				continue
			var alpha := (sin(t * 1.2 + fly.z) + 1.0) * 0.23
			alpha *= world.foundation.clock.darkness()
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
			if not view.intersects(rect):
				continue
			var color := Color(1, 0.3, 0.5, 0.28)
			if shape.get_meta("kind") == "water":
				color = Color(0.1, 0.65, 1, 0.3)
			draw_rect(rect, color)
			draw_rect(rect, Color(color, 0.9), false, 0.5)
		draw_circle(world.hero.position + Vector2(0, -3), 4, Color(0.1, 1, 0.5, 0.8), false, 0.8)
