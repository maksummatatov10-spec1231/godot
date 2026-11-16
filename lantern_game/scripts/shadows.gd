extends Node2D
## A shared ground plane, below ALL Y-sorted actors: shadows never paint a face.
## Project the actual current texture/region, not a generic oval or baked blob.
const INK = preload("res://scripts/cast_shadow.gdshader")
const PROJECTION = Transform2D(Vector2(1, 0), Vector2(-0.85, -0.48), Vector2.ZERO)
var world: Node2D
var casters: Array[Dictionary] = []
var moving: Array[Dictionary] = []
var shared_ground: Dictionary = {}
var contact_profiles: Dictionary = {}
var contact_images: Dictionary = {}
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
	entry.contact_local_y = contact_local_y(entry)
	phase = contact_foot(entry).x * 0.15
	entry.phase = phase
	entry.receiver = light_depth.register_receiver(
		source, foot, windy, crown_height, entry.contact_local_y
	)
	_apply_ground_material(entry)
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
	refresh_contact(entry)
	var foot := contact_foot(entry)
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
			refresh_contact(entry)
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


func contact_local_y(entry: Dictionary) -> float:
	var source: Sprite2D = entry.source
	if entry.foot is CharacterBody2D:
		source = entry.foot.sprite
	var region := (
		source.region_rect
		if source.region_enabled
		else Rect2(Vector2.ZERO, source.texture.get_size())
	)
	var signature := [source.texture.get_instance_id(), region, source.get_rect(), source.flip_v]
	if source.get_meta("contact_signature", []) == signature:
		return source.get_meta("contact_local_y")
	var key := str(
		source.texture.get_instance_id(), ":", region, ":", source.get_rect(), ":", source.flip_v
	)
	if not contact_profiles.has(key):
		var texture_id := source.texture.get_instance_id()
		if not contact_images.has(texture_id):
			contact_images[texture_id] = source.texture.get_image()
		var image: Image = contact_images[texture_id]
		var used := image.get_region(Rect2i(region)).get_used_rect()
		var bottom := float(used.end.y) - 0.5
		if source.flip_v:
			bottom = region.size.y - float(used.position.y) - 0.5
		contact_profiles[key] = source.get_rect().position.y + bottom
	source.set_meta("contact_signature", signature)
	source.set_meta("contact_local_y", contact_profiles[key])
	return contact_profiles[key]


func contact_foot(entry: Dictionary) -> Vector2:
	var anchor: Sprite2D = entry.source
	if entry.foot is CharacterBody2D:
		anchor = entry.foot.sprite
	return anchor.global_transform * Vector2(0, entry.contact_local_y)


func _apply_ground_material(entry: Dictionary) -> void:
	var key := Vector3(
		1.0 if entry.windy else 0.0,
		entry.crown_height if entry.windy else 0.0,
		entry.contact_local_y
	)
	if not shared_ground.has(key):
		var ink := ShaderMaterial.new()
		ink.shader = INK
		ink.set_shader_parameter("wind", entry.windy)
		ink.set_shader_parameter("crown_height", entry.crown_height)
		ink.set_shader_parameter("feet_local_y", entry.contact_local_y)
		shared_ground[key] = ink
	entry.shadow.material = shared_ground[key]


func refresh_contact(entry: Dictionary) -> void:
	var source: Sprite2D = entry.source
	var local_contact := contact_local_y(entry)
	if entry.contact_local_y != local_contact:
		entry.contact_local_y = local_contact
		_apply_ground_material(entry)
		entry.receiver.ink = light_depth.receiver_material(
			source, entry.windy, entry.crown_height, local_contact
		)
