extends Control
## A restrained sky accent in the top-down composition; never intercepts input.
var foundation: Node


func _draw() -> void:
	if foundation.world.mode != "play":
		return
	var strength: float = foundation.clock.darkness()
	if strength < 0.03:
		return
	var center := Vector2(588, 34)
	for i in range(4, 0, -1):
		draw_circle(center, 10.0 + i * 5.0, Color(0.60, 0.76, 0.95, strength * 0.018))
	draw_circle(center, 10, Color(0.78, 0.86, 0.92, strength * 0.85))
	draw_circle(center + Vector2(-2, -2), 8, Color(0.94, 0.94, 0.83, strength))
	for crater in [Vector3(-4, -1, 2), Vector3(2, 4, 2), Vector3(4, -4, 1)]:
		draw_circle(
			center + Vector2(crater.x, crater.y), crater.z, Color(0.59, 0.69, 0.76, strength * 0.5)
		)
	for star in [Vector2(553, 19), Vector2(614, 61), Vector2(565, 63), Vector2(619, 16)]:
		draw_rect(Rect2(star, Vector2.ONE), Color(0.82, 0.9, 1, strength * 0.7))
