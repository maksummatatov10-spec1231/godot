extends Node
## Directional light-space depth maps made from actual current sprite alpha.
## q = screen_pixel + (0.85, 1.48) * height; height = feet_y - screen_pixel.y.
## All strips are sorted by height, NOT by object order or the main Y-sort.
const DEPTH_SHADER = preload("res://scripts/light_depth.gdshader")
const MAP_SIZE = Vector2i(1536, 1152)
const HEIGHT_RANGE = 128.0
var static_view := SubViewport.new()
var moving_view := SubViewport.new()
var static_mesh := MeshInstance2D.new()
var moving_mesh := MeshInstance2D.new()
var static_ink := ShaderMaterial.new()
var moving_ink := ShaderMaterial.new()
var atlas: ImageTexture
var atlas_rects: Dictionary = {}
var textures: Array[Texture2D] = []
var built := false
var shutting_down := false
var receiver_materials: Array[Dictionary] = []


func _ready() -> void:
	_create_target(static_view, static_mesh, static_ink)
	_create_target(moving_view, moving_mesh, moving_ink)


func _create_target(view: SubViewport, mesh: MeshInstance2D, ink: ShaderMaterial) -> void:
	view.size = MAP_SIZE
	view.disable_3d = true
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	ink.shader = DEPTH_SHADER
	mesh.material = ink
	mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.add_child(mesh)


func register_receiver(source: Sprite2D, foot: Node2D, windy: bool) -> void:
	var ink: ShaderMaterial = source.material
	if ink == null:
		ink = ShaderMaterial.new()
		ink.shader = preload("res://scripts/foliage.gdshader")
		ink.set_shader_parameter("wind", windy)
		source.material = ink
	ink.set_shader_parameter("static_depth", static_view.get_texture())
	ink.set_shader_parameter("moving_depth", moving_view.get_texture())
	ink.set_shader_parameter("feet_y", foot.global_position.y)
	receiver_materials.append({"ink": ink, "foot": foot})


func build_atlas(entries: Array[Dictionary]) -> void:
	atlas_rects.clear()
	for entry in entries:
		var texture: Texture2D = entry.source.texture
		if texture != null and not textures.has(texture):
			textures.append(texture)
	# Tools can be switched after atlas creation, so reserve every equipment sheet.
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
	static_mesh.texture = atlas
	moving_mesh.texture = atlas


func update(entries: Array[Dictionary], elapsed: float) -> void:
	if shutting_down:
		return
	if not built:
		build_atlas(entries)
		static_mesh.mesh = _build_mesh(entries, false)
		built = true
	moving_mesh.mesh = _build_mesh(entries, true)
	static_ink.set_shader_parameter("wind_time", elapsed)
	moving_ink.set_shader_parameter("wind_time", elapsed)
	for receiver in receiver_materials:
		if is_instance_valid(receiver.foot):
			receiver.ink.set_shader_parameter("feet_y", receiver.foot.global_position.y)
			receiver.ink.set_shader_parameter("wind_time", elapsed)


func invalidate() -> void:
	built = false


func _build_mesh(entries: Array[Dictionary], dynamic: bool) -> ArrayMesh:
	var rows: Array[Dictionary] = []
	for entry in entries:
		if entry.follows != dynamic or not is_instance_valid(entry.source):
			continue
		var source: Sprite2D = entry.source
		if not source.is_visible_in_tree() or source.texture == null:
			continue
		var image_rect: Rect2 = atlas_rects[source.texture.get_instance_id()]
		var frame := (
			source.region_rect
			if source.region_enabled
			else Rect2(Vector2.ZERO, source.texture.get_size())
		)
		var bounds := source.get_rect()
		if frame.size.y <= 0.0:
			continue
		var foot: Vector2 = entry.foot.global_position
		for row in range(int(frame.size.y)):
			var y := bounds.position.y + float(row)
			var center: Vector2 = source.global_transform * Vector2(0, y + 0.5)
			var height := clampf(foot.y - center.y, 0.0, HEIGHT_RANGE - 1.0)
			rows.append(
				{
					"height": height,
					"source": source,
					"entry": entry,
					"row": row,
					"bounds": bounds,
					"frame": frame,
					"atlas": image_rect
				}
			)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.height < b.height)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for row in rows:
		_append_row(row, vertices, uvs, colors)
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


func _append_row(
	row: Dictionary, vertices: PackedVector2Array, uvs: PackedVector2Array, colors: PackedColorArray
) -> void:
	var source: Sprite2D = row.source
	var bounds: Rect2 = row.bounds
	var frame: Rect2 = row.frame
	var atlas_rect: Rect2 = row.atlas
	var entry: Dictionary = row.entry
	var foot: Vector2 = entry.foot.global_position
	var y: float = bounds.position.y + float(row.row)
	var left := bounds.position.x
	var right := bounds.end.x
	var points := [Vector2(left, y), Vector2(right, y), Vector2(right, y + 1), Vector2(left, y + 1)]
	for index in [0, 1, 2, 0, 2, 3]:
		var local: Vector2 = points[index]
		var pixel: Vector2 = source.global_transform * local
		var height := foot.y - pixel.y
		var q := project_pixel(pixel, foot.y)
		var wind_weight := 0.0
		if entry.windy:
			wind_weight = pow(clampf(-local.y / maxf(entry.crown_height, 1.0), 0, 1), 2)
		var color := Color(
			clampf(height / HEIGHT_RANGE, 0, 1),
			fposmod(entry.phase, TAU) / TAU,
			fposmod(entry.phase * 0.7, TAU) / TAU,
			wind_weight
		)
		var uv := Vector2(local.x - left, float(row.row) + (1.0 if index >= 2 else 0.0))
		if source.flip_h:
			uv.x = frame.size.x - uv.x
		if source.flip_v:
			uv.y = frame.size.y - uv.y
		vertices.append(q)
		uvs.append((atlas_rect.position + frame.position + uv) / Vector2(2048, 2048))
		colors.append(color)


func project_pixel(pixel: Vector2, feet_y: float) -> Vector2:
	return pixel + Vector2(0.85, 1.48) * (feet_y - pixel.y)


func release_render_targets() -> void:
	# Break cross-viewport texture references WHILE the renderer is still alive.
	shutting_down = true
	RenderingServer.force_sync()
	if DisplayServer.get_name() != "headless":
		# Readback is a GPU completion fence before detaching dependent targets.
		static_view.get_texture().get_image()
		moving_view.get_texture().get_image()
	for receiver in receiver_materials:
		receiver.ink.set_shader_parameter("static_depth", null)
		receiver.ink.set_shader_parameter("moving_depth", null)
	receiver_materials.clear()
	static_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	moving_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	static_mesh.mesh = null
	moving_mesh.mesh = null
	static_mesh.texture = null
	moving_mesh.texture = null
	static_mesh.material = null
	moving_mesh.material = null
