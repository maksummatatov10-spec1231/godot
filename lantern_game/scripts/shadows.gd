extends Node2D
## A shared ground plane, below ALL Y-sorted actors: shadows never paint a face.
## Project the actual current texture/region, not a generic oval or baked blob.
const INK = preload("res://scripts/cast_shadow.gdshader")
const PROJECTION = Transform2D(Vector2(1, 0), Vector2(-0.85, -0.48), Vector2.ZERO)
var world: Node2D
var casters: Array[Dictionary] = []
var moving: Array[Dictionary] = []
var wind_materials: Array[ShaderMaterial] = []


func register(
	source: Sprite2D,
	foot: Node2D,
	follows: bool = false,
	windy: bool = false,
	crown_height: float = 32.0,
	phase: float = 0.0
) -> Sprite2D:
	var silhouette := Sprite2D.new()
	var ink := ShaderMaterial.new()
	ink.shader = INK
	ink.set_shader_parameter("wind", windy)
	ink.set_shader_parameter("crown_height", crown_height)
	ink.set_shader_parameter("phase", phase)
	silhouette.material = ink
	add_child(silhouette)
	var entry := {"source": source, "foot": foot, "shadow": silhouette}
	casters.append(entry)
	if follows:
		moving.append(entry)
	if windy:
		wind_materials.append(ink)
	sync(entry)
	return silhouette


func sync(entry: Dictionary) -> void:
	var source: Sprite2D = entry.source
	var silhouette: Sprite2D = entry.shadow
	var foot: Vector2 = entry.foot.global_position
	silhouette.texture = source.texture
	silhouette.region_enabled = source.region_enabled
	silhouette.region_rect = source.region_rect
	silhouette.centered = source.centered
	silhouette.offset = source.offset
	silhouette.flip_h = source.flip_h
	silhouette.flip_v = source.flip_v
	silhouette.visible = source.is_visible_in_tree()
	var projected := PROJECTION * source.global_transform
	projected.origin += foot - PROJECTION * foot
	silhouette.global_transform = projected


func _process(_delta: float) -> void:
	for entry in moving:
		if is_instance_valid(entry.source):
			sync(entry)
		else:
			entry.shadow.hide()
	for ink in wind_materials:
		ink.set_shader_parameter("wind_time", world.elapsed)
	queue_redraw()


func _draw() -> void:
	if not world.particles_enabled:
		return
	for leaf in world.leaves:
		var sample: Vector3 = world.leaf_sample(leaf)
		var p := Vector2(sample.x, sample.y) + Vector2(0.85, 0.48) * sample.z
		var phase := fposmod(world.elapsed + leaf.z, 12.0) / 12.0
		var alpha := smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.82, 1.0, phase))
		draw_set_transform(p, 0.0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 1.5, Color(0.075, 0.12, 0.18, alpha * 0.19))
	draw_set_transform(Vector2.ZERO)
