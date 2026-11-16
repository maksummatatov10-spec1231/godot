extends Node
## Camera-local light maps. Static geometry is cached in clipped spatial tiles;
## moving geometry is rebuilt only for changed, relevant poses, never the world.
const DEPTH_SHADER = preload("res://scripts/light_depth.gdshader")
const RECEIVER_SHADER = preload("res://scripts/foliage.gdshader")
const MAP_SIZE = Vector2i(1536, 1152)
const HEIGHT_RANGE = 128.0
const RECEIVER_HEIGHT = 80.0
const TILE = 192
const CROP_STEP = 32.0
var world: Node2D
var static_view := SubViewport.new()
var moving_view := SubViewport.new()
var moving_mesh := MeshInstance2D.new()
var moving_ink := ShaderMaterial.new()
var atlas: ImageTexture
var atlas_rects: Dictionary = {}
var textures: Array[Texture2D] = []
var built := false
var shutting_down := false
var receiver_materials: Array[Dictionary] = []
var shared_receivers: Dictionary = {}
var static_bins: Dictionary = {}
var static_tiles: Dictionary = {}
var active_tiles: Array[Vector2i] = []
var light_rect := Rect2()
var selected_moving: Array[Dictionary] = []
var last_signature: Array = []
var last_time := -1.0
var mesh_rebuilds := 0
var pose_builds := 0
var active_static_count := 0


func _ready() -> void:
	_create_target(static_view)
	_create_target(moving_view)
	moving_ink.shader = DEPTH_SHADER
	moving_mesh.material = moving_ink
	moving_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moving_view.add_child(moving_mesh)


func _create_target(view: SubViewport) -> void:
	view.size = Vector2i(32, 32)
	view.disable_3d = true
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)


func register_receiver(
	source: Sprite2D, foot: Node2D, windy: bool, crown_height: float = 32.0
) -> void:
	# MODEL_MATRIX already contains source position; only a fixed sprite/feet offset
	# is needed. Shared wind/crop globals replace thousands of per-frame API writes.
	var offset := foot.global_position.y - source.global_position.y
	var key := Vector3(1.0 if windy else 0.0, crown_height if windy else 0.0, offset)
	if not shared_receivers.has(key):
		var ink := ShaderMaterial.new()
		ink.shader = RECEIVER_SHADER
		ink.set_shader_parameter("wind", windy)
		ink.set_shader_parameter("crown_height", crown_height)
		ink.set_shader_parameter("feet_offset", offset)
		ink.set_shader_parameter("static_depth", static_view.get_texture())
		ink.set_shader_parameter("moving_depth", moving_view.get_texture())
		shared_receivers[key] = ink
	source.material = shared_receivers[key]
	receiver_materials.append({"ink": source.material, "foot": foot})


func build_atlas(entries: Array[Dictionary]) -> void:
	atlas_rects.clear()
	for entry in entries:
		var texture: Texture2D = entry.source.texture
		if texture != null and not textures.has(texture):
			textures.append(texture)
	for tool_name in ["Katana", "Axe", "Pickaxe", "Net", "Hammer"]:
		var texture: Texture2D = load(
			"res://assets/ninja/Actor/CharacterAnimated/Weapon/" + tool_name + ".png"
		)
		if not textures.has(texture):
			textures.append(texture)
	var canvas := Image.create(2048, 2048, false, Image.FORMAT_RGBA8)
	var pen := Vector2i(1, 1)
	var row_height := 0
	for texture in textures:
		var image := texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		var dimensions := image.get_size()
		if pen.x + dimensions.x + 1 > canvas.get_width():
			pen.x = 1
			pen.y += row_height + 2
			row_height = 0
		assert(pen.y + dimensions.y + 1 <= canvas.get_height(), "Light atlas capacity")
		canvas.blit_rect(image, Rect2i(Vector2i.ZERO, dimensions), pen)
		atlas_rects[texture.get_instance_id()] = Rect2(Vector2(pen), Vector2(dimensions))
		pen.x += dimensions.x + 2
		row_height = maxi(row_height, dimensions.y)
	atlas = ImageTexture.create_from_image(canvas)
	moving_mesh.texture = atlas


func projected_bounds(entry: Dictionary) -> Rect2:
	var source: Sprite2D = entry.source
	var bounds := source.get_rect()
	var foot: Vector2 = entry.foot.global_position
	var points := [
		bounds.position,
		bounds.end,
		Vector2(bounds.end.x, bounds.position.y),
		Vector2(bounds.position.x, bounds.end.y)
	]
	var result := Rect2(project_pixel(source.global_transform * points[0], foot.y), Vector2.ZERO)
	for point in points:
		result = result.expand(project_pixel(source.global_transform * point, foot.y))
	return result.grow(3.0)  # Wind can move a silhouette across a tile edge.


func crop_for_screen(screen: Rect2) -> Rect2:
	# q lies down-right of a raised receiver; include offscreen blockers whose
	# projected silhouette can reach these q values. No whole-world guard band.
	var expanded := screen.grow(8.0)
	expanded = expanded.expand(expanded.end + Vector2(0.85, 1.48) * RECEIVER_HEIGHT)
	var first := (expanded.position / CROP_STEP).floor() * CROP_STEP
	var last := (expanded.end / CROP_STEP).ceil() * CROP_STEP
	return Rect2(first, last - first).intersection(Rect2(-128, -128, 1792, 1408))


func _index_static(entries: Array[Dictionary]) -> void:
	static_bins.clear()
	for entry in entries:
		if entry.follows:
			continue
		entry.light_bounds = projected_bounds(entry)
		var bounds: Rect2 = entry.light_bounds
		for y in range(int(floor(bounds.position.y / TILE)), int(floor(bounds.end.y / TILE)) + 1):
			for x in range(
				int(floor(bounds.position.x / TILE)), int(floor(bounds.end.x / TILE)) + 1
			):
				var cell := Vector2i(x, y)
				if not static_bins.has(cell):
					static_bins[cell] = []
				static_bins[cell].append(entry)


func _select_tiles() -> void:
	for cell in active_tiles:
		static_tiles[cell].hide()
	active_tiles.clear()
	var selected_ids := {}
	for y in range(
		int(floor(light_rect.position.y / TILE)), int(floor((light_rect.end.y - 0.01) / TILE)) + 1
	):
		for x in range(
			int(floor(light_rect.position.x / TILE)),
			int(floor((light_rect.end.x - 0.01) / TILE)) + 1
		):
			var cell := Vector2i(x, y)
			if not static_bins.has(cell):
				continue
			if not static_tiles.has(cell):
				var tile_mesh := MeshInstance2D.new()
				var ink := ShaderMaterial.new()
				ink.shader = DEPTH_SHADER
				ink.set_shader_parameter("clip_enabled", true)
				ink.set_shader_parameter("clip_rect", Vector4(x * TILE, y * TILE, TILE, TILE))
				tile_mesh.material = ink
				tile_mesh.texture = atlas
				tile_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				static_view.add_child(tile_mesh)
				tile_mesh.mesh = _build_cached_mesh(static_bins[cell])
				static_tiles[cell] = tile_mesh
			var tile_mesh: MeshInstance2D = static_tiles[cell]
			tile_mesh.position = -light_rect.position
			tile_mesh.show()
			active_tiles.append(cell)
			for entry in static_bins[cell]:
				selected_ids[entry.source.get_instance_id()] = true
	active_static_count = selected_ids.size()


func update(entries: Array[Dictionary], elapsed: float) -> void:
	if shutting_down:
		return
	var initialized := built
	if not built:
		build_atlas(entries)
		_index_static(entries)
		built = true
	var requested := crop_for_screen(world.world_view_rect())
	var crop_changed := requested != light_rect or not initialized
	if crop_changed:
		light_rect = requested
		static_view.size = Vector2i(light_rect.size)
		moving_view.size = static_view.size
		RenderingServer.global_shader_parameter_set(
			"light_rect",
			Vector4(
				light_rect.position.x, light_rect.position.y, light_rect.size.x, light_rect.size.y
			)
		)
		_select_tiles()
		moving_mesh.position = -light_rect.position
	selected_moving.clear()
	var signature: Array = []
	var moving_wind := false
	for entry in world.shadows.moving:
		var source: Sprite2D = entry.source
		if not is_instance_valid(source) or not source.is_visible_in_tree():
			continue
		if not entry.light_bounds.intersects(light_rect):
			continue
		selected_moving.append(entry)
		signature.append(
			[
				source.get_instance_id(),
				source.texture.get_instance_id(),
				source.region_rect,
				source.global_transform,
				source.visible
			]
		)
		moving_wind = moving_wind or entry.windy
	var moving_changed := signature != last_signature or not initialized
	if moving_changed:
		moving_mesh.mesh = _build_cached_mesh(selected_moving)
		last_signature = signature
		mesh_rebuilds += 1
	var time_changed := elapsed != last_time
	static_view.render_target_update_mode = (
		SubViewport.UPDATE_ONCE if crop_changed or time_changed else SubViewport.UPDATE_DISABLED
	)
	moving_view.render_target_update_mode = (
		SubViewport.UPDATE_ONCE
		if moving_changed or crop_changed or (time_changed and moving_wind)
		else SubViewport.UPDATE_DISABLED
	)
	last_time = elapsed


func invalidate() -> void:
	built = false
	for tile_mesh in static_tiles.values():
		tile_mesh.queue_free()
	static_tiles.clear()
	active_tiles.clear()


func _entry_rows(entry: Dictionary) -> Array:
	var source: Sprite2D = entry.source
	var frame := (
		source.region_rect
		if source.region_enabled
		else Rect2(Vector2.ZERO, source.texture.get_size())
	)
	var bounds := source.get_rect()
	var foot: Vector2 = entry.foot.global_position
	var transform := source.global_transform
	transform.origin -= foot
	var key := [
		source.texture.get_instance_id(), frame, bounds, transform, source.flip_h, source.flip_v
	]
	if entry.get("pose_key", []) == key:
		return entry.pose_rows
	var rows: Array = []
	var image_rect: Rect2 = atlas_rects[source.texture.get_instance_id()]
	for row in range(int(frame.size.y)):
		var y := bounds.position.y + float(row)
		var vertices := PackedVector2Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		var points := [
			Vector2(bounds.position.x, y),
			Vector2(bounds.end.x, y),
			Vector2(bounds.end.x, y + 1),
			Vector2(bounds.position.x, y + 1)
		]
		for index in [0, 1, 2, 0, 2, 3]:
			var local: Vector2 = points[index]
			var pixel: Vector2 = transform * local
			var height := -pixel.y
			var weight := (
				pow(clampf(-local.y / maxf(entry.crown_height, 1.0), 0, 1), 2)
				if entry.windy
				else 0.0
			)
			vertices.append(project_pixel(pixel, 0.0))
			var uv := Vector2(
				local.x - bounds.position.x, float(row) + (1.0 if index >= 2 else 0.0)
			)
			if source.flip_h:
				uv.x = frame.size.x - uv.x
			if source.flip_v:
				uv.y = frame.size.y - uv.y
			uvs.append((image_rect.position + frame.position + uv) / Vector2(2048, 2048))
			colors.append(
				Color(
					clampf(height / HEIGHT_RANGE, 0, 1),
					fposmod(entry.phase, TAU) / TAU,
					fposmod(entry.phase * 0.7, TAU) / TAU,
					weight
				)
			)
		rows.append(
			{
				"height": -(transform * Vector2(0, y + 0.5)).y,
				"vertices": vertices,
				"uvs": uvs,
				"colors": colors,
				"origin": foot
			}
		)
	entry.pose_key = key
	entry.pose_rows = rows
	pose_builds += 1
	return rows


func _build_cached_mesh(entries: Array) -> ArrayMesh:
	var rows: Array = []
	for entry in entries:
		if not is_instance_valid(entry.source) or entry.source.texture == null:
			continue
		var foot: Vector2 = entry.foot.global_position
		for row in _entry_rows(entry):
			row.origin = foot
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.height < b.height)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for row in rows:
		for vertex in row.vertices:
			vertices.append(vertex + row.origin)
		uvs.append_array(row.uvs)
		colors.append_array(row.colors)
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func project_pixel(pixel: Vector2, feet_y: float) -> Vector2:
	return pixel + Vector2(0.85, 1.48) * (feet_y - pixel.y)


func release_render_targets() -> void:
	shutting_down = true
	RenderingServer.force_sync()
	if DisplayServer.get_name() != "headless":
		static_view.get_texture().get_image()
		moving_view.get_texture().get_image()
	for ink in shared_receivers.values():
		ink.set_shader_parameter("static_depth", null)
		ink.set_shader_parameter("moving_depth", null)
	receiver_materials.clear()
	static_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	moving_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for tile_mesh in static_tiles.values():
		tile_mesh.mesh = null
		tile_mesh.texture = null
		tile_mesh.material = null
	moving_mesh.mesh = null
	moving_mesh.texture = null
	moving_mesh.material = null
