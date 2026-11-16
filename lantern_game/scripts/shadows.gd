extends Node2D
## A shared ground plane, below ALL Y-sorted actors: shadows never paint a face.
## Project the actual current texture/region, not a generic oval or baked blob.
const INK = preload("res://scripts/cast_shadow.gdshader")
const PROJECTION = Transform2D(Vector2(1, 0), Vector2(-0.85, -0.48), Vector2.ZERO)
var world: Node2D
var casters: Array[Dictionary] = []
var moving: Array[Dictionary] = []
var shared_ground: Dictionary = {}
var visible_leaves: Array[Vector3] = []
var visible_fireflies: Array[Vector3] = []
var visibility_rect := Rect2()
var last_time := -1.0
var last_particles := true
var light_depth := preload("res://scripts/light_depth.gd").new()


func _ready() -> void:
	light_depth.world = world
	add_child(light_depth)


func register(
	source: Sprite2D,
	foot: Node2D,
	follows: bool = false,
	windy: bool = false,
	crown_height: float = 32.0,
	phase: float = 0.0
) -> Sprite2D:
	var silhouette := Sprite2D.new()
	var key := Vector2(1.0 if windy else 0.0, crown_height if windy else 0.0)
	if not shared_ground.has(key):
		var ink := ShaderMaterial.new()
		ink.shader = INK
		ink.set_shader_parameter("wind", windy)
		ink.set_shader_parameter("crown_height", crown_height)
		shared_ground[key] = ink
	silhouette.material = shared_ground[key]
	phase = foot.global_position.x * 0.15
	add_child(silhouette)
	var entry := {
		"source": source,
		"foot": foot,
		"shadow": silhouette,
		"follows": follows,
		"windy": windy,
		"crown_height": crown_height,
		"phase": phase
	}
	light_depth.register_receiver(source, foot, windy, crown_height)
	visibility_rect = Rect2()
	light_depth.invalidate()
	casters.append(entry)
	if follows:
		moving.append(entry)
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
	var view: Rect2 = world.world_view_rect()
	var first := (view.position / 32.0).floor() * 32.0
	var requested := Rect2(first, ((view.end - first) / 32.0).ceil() * 32.0).grow(32.0)
	var moved := requested != visibility_rect
	if moved:
		visibility_rect = requested
		for entry in casters:
			if entry.follows:
				continue
			entry.light_bounds = light_depth.projected_bounds(entry)
			entry.shadow.visible = entry.light_bounds.intersects(visibility_rect)
		visible_leaves.clear()
		visible_fireflies.clear()
		var emitters := visibility_rect.grow(96.0)
		for leaf in world.leaves:
			if emitters.has_point(Vector2(leaf.x, leaf.y)):
				visible_leaves.append(leaf)
		for fly in world.fireflies:
			if emitters.has_point(Vector2(fly.x, fly.y)):
				visible_fireflies.append(fly)
	for entry in moving:
		if is_instance_valid(entry.source):
			entry.light_bounds = light_depth.projected_bounds(entry)
			if entry.light_bounds.intersects(visibility_rect):
				sync(entry)
			else:
				entry.shadow.hide()
		else:
			entry.shadow.hide()
	if world.elapsed != last_time:
		RenderingServer.global_shader_parameter_set("wind_time", world.elapsed)
	light_depth.update(casters, world.elapsed)
	if (
		moved
		or world.particles_enabled != last_particles
		or (world.elapsed != last_time and world.particles_enabled)
	):
		queue_redraw()
	last_time = world.elapsed
	last_particles = world.particles_enabled


func performance_stats() -> Dictionary:
	return {
		"registered_casters": casters.size(),
		"active_static_casters": light_depth.active_static_count,
		"active_moving_casters": light_depth.selected_moving.size(),
		"active_static_tiles": light_depth.active_tiles.size(),
		"cached_static_tiles": light_depth.static_tiles.size(),
		"depth_pixels": light_depth.static_view.size.x * light_depth.static_view.size.y * 2,
		"depth_size": [light_depth.static_view.size.x, light_depth.static_view.size.y],
		"shared_receiver_materials": light_depth.shared_receivers.size(),
		"shared_ground_materials": shared_ground.size(),
		"moving_mesh_rebuilds": light_depth.mesh_rebuilds,
		"pose_templates_built": light_depth.pose_builds,
		"visible_leaf_emitters": visible_leaves.size()
	}


func _draw() -> void:
	if not world.particles_enabled:
		return
	for leaf in visible_leaves:
		var sample: Vector3 = world.leaf_sample(leaf)
		var p := Vector2(sample.x, sample.y) + Vector2(0.85, 0.48) * sample.z
		if not visibility_rect.has_point(p):
			continue
		var phase := fposmod(world.elapsed + leaf.z, 12.0) / 12.0
		var alpha := smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.82, 1.0, phase))
		draw_set_transform(p, 0.0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 1.5, Color(0.075, 0.12, 0.18, alpha * 0.19))
	draw_set_transform(Vector2.ZERO)
