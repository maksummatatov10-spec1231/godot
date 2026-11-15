extends Node3D
## Deterministic handcrafted clearing, with seeded forest dressing around it.

const PLAYER = preload("res://scripts/player.gd")
const TARGET = preload("res://scripts/target.gd")
const HUD = preload("res://scripts/hud.gd")
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var hud: CanvasLayer
var environment: Environment
var targets: Array[Node3D] = []
var loaded_models: Dictionary = {}
var foliage_materials: Dictionary = {}
var tree_batches: Dictionary = {}
var capture_mode := false
var high_quality := true


func _ready() -> void:
	rng.seed = 730221
	capture_mode = OS.get_cmdline_user_args().has("--self-test")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_mode = true
	ambient_sound()
	lighting()
	terrain()
	forest()
	landmarks()
	player = CharacterBody3D.new()
	player.set_script(PLAYER)
	player.name = "Warden"
	player.position = Vector3(0, height_at(0, 7) + 0.1, 7)
	add_child(player)
	hud = CanvasLayer.new()
	hud.set_script(HUD)
	add_child(hud)
	hud.setup(player, self)
	player.hud = hud
	if not capture_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_suite.call_deferred(arg.trim_prefix("--capture-dir="))
	print("FOREST_READY trees=280 ground_cover=3400 seed=730221")


static func height_at(x: float, z: float) -> float:
	var clearing := smoothstep(9.0, 28.0, Vector2(x, z).length())
	return clearing * (sin(x * 0.09) * 1.8 + cos(z * 0.11) * 1.2 + 1.0)


func ambient_sound() -> void:
	var sound := AudioStreamPlayer.new()
	sound.stream = load("res://audio/forest-air.ogg")
	sound.stream.loop = true
	sound.volume_db = -6
	add_child(sound)
	sound.play()


func lighting() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	world.environment = environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/day_sky.gdshader")
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.ssao_enabled = true
	environment.ssao_radius = 1.3
	environment.ssao_intensity = 1.5
	environment.ssr_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("aac5cf")
	environment.fog_density = 0.0018
	environment.fog_sun_scatter = 0.55
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.003
	environment.volumetric_fog_albedo = Color("c5d4d0")
	environment.volumetric_fog_length = 75.0
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "LateMorningSun"
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.8
	sun.light_volumetric_fog_energy = 1.2
	add_child(sun)


func terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-48, 48):
		for x in range(-48, 48):
			for offset in [
				Vector2(0, 0),
				Vector2(1, 0),
				Vector2(0, 1),
				Vector2(1, 0),
				Vector2(1, 1),
				Vector2(0, 1)
			]:
				var p: Vector2 = Vector2(x, z) * 1.7 + offset * 1.7
				surface.set_uv(p * 0.1)
				surface.add_vertex(Vector3(p.x, height_at(p.x, p.y), p.y))
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "RollingForestFloor"
	ground.mesh = surface.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	ground.material_override = mat
	add_child(ground)
	ground.create_trimesh_collision()
	var lake := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 6.0
	disk.bottom_radius = 6.0
	disk.height = 0.08
	disk.radial_segments = 64
	lake.mesh = disk
	lake.position = Vector3(-12, 0.13, -3)
	lake.scale = Vector3(1, 1, 1.6)
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	lake.material_override = water
	add_child(lake)


func model(model_name: String) -> PackedScene:
	if not loaded_models.has(model_name):
		loaded_models[model_name] = load("res://assets/nature/" + model_name + ".gltf")
	return loaded_models[model_name]


func plant(model_name: String, pos: Vector3, size: float, collide := false) -> Node3D:
	var obj := model(model_name).instantiate() as Node3D
	obj.position = pos
	obj.rotation.y = rng.randf_range(-PI, PI)
	obj.scale = Vector3.ONE * size
	add_child(obj)
	for mesh in obj.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original: Material = mesh.get_active_material(surface)
			if original is StandardMaterial3D and "Leaves" in original.resource_name:
				mesh.set_surface_override_material(surface, wind_material(original))
	if model_name.begins_with("Rock_Medium"):
		for mesh in obj.find_children("*", "MeshInstance3D", true, false):
			mesh.create_convex_collision()
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var capsule := CylinderShape3D.new()
		capsule.radius = 0.32 * size
		capsule.height = 5.5 * size
		shape.shape = capsule
		shape.position.y = capsule.height / 2.0
		body.add_child(shape)
		add_child(body)
		body.position = pos
	return obj


func forest() -> void:
	var trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "Pine_1", "Pine_3"]
	# Framing trees are intentionally placed; the remaining forest is seeded.
	for p in [
		Vector3(-6, 0, 3),
		Vector3(6.5, 0, 2),
		Vector3(-8, 0, -8),
		Vector3(8, 0, -7),
		Vector3(-5.5, 0, -15),
		Vector3(6, 0, -18)
	]:
		p.y = height_at(p.x, p.z)
		add_tree(trees[rng.randi_range(0, 2)], p, rng.randf_range(1.2, 1.6))
	for i in range(274):
		var angle := rng.randf_range(-PI, PI)
		var radius := sqrt(rng.randf_range(180, 4000))
		var p := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		if abs(p.x) < 3.5 and p.z < 15:
			p.x += 7.0
		p.y = height_at(p.x, p.z)
		add_tree(trees[i % trees.size()], p, rng.randf_range(0.95, 1.65))
	build_tree_batches()
	for i in range(100):
		var p := scatter_point(42.0)
		if abs(p.x) < 3.0:
			continue
		plant("Bush_Common" if i % 3 == 0 else "Fern_1", p, rng.randf_range(0.65, 1.2))
	for i in range(40):
		var p := scatter_point(38.0)
		if Vector2(p.x, p.z).length() < 4.0:
			continue
		plant("Rock_Medium_1" if i % 2 else "Rock_Medium_2", p, rng.randf_range(0.35, 0.85))
	for species in ["Grass_Common_Short", "Grass_Wispy_Tall", "Flower_3_Group", "Flower_4_Group"]:
		ground_cover(
			species, 200 if "Flower" in species else (1800 if "Short" in species else 1200)
		)


func add_tree(species: String, pos: Vector3, size: float) -> void:
	var key := species + str(int(pos.x > 0)) + str(int(pos.z > 0))
	if not tree_batches.has(key):
		tree_batches[key] = {"species": species, "transforms": []}
	var orientation := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * size)
	tree_batches[key].transforms.append(Transform3D(orientation, pos))
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.32 * size
	cylinder.height = 5.5 * size
	collision.shape = cylinder
	collision.position.y = cylinder.height / 2.0
	body.add_child(collision)
	add_child(body)
	body.position = pos


func build_tree_batches() -> void:
	for entry in tree_batches.values():
		var source: Node3D = model(entry.species).instantiate()
		for piece in source.find_children("*", "MeshInstance3D", true, false):
			var batch := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = piece.mesh.duplicate()
			for surface in range(mm.mesh.get_surface_count()):
				var original: Material = piece.get_active_material(surface)
				if original is StandardMaterial3D and "Leaves" in original.resource_name:
					mm.mesh.surface_set_material(surface, wind_material(original))
			mm.instance_count = entry.transforms.size()
			for i in range(mm.instance_count):
				mm.set_instance_transform(i, entry.transforms[i] * piece.transform)
			batch.multimesh = mm
			add_child(batch)
		source.free()


func wind_material(original: StandardMaterial3D) -> ShaderMaterial:
	var key := original.resource_name
	if not foliage_materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/foliage.gdshader")
		mat.set_shader_parameter("albedo_tex", original.albedo_texture)
		mat.set_shader_parameter("tint", original.albedo_color)
		mat.set_shader_parameter("bend", 0.022)
		foliage_materials[key] = mat
	return foliage_materials[key]


func scatter_point(radius: float) -> Vector3:
	var p := Vector3(rng.randf_range(-radius, radius), 0, rng.randf_range(-radius, radius))
	p.y = height_at(p.x, p.z)
	return p


func ground_cover(species: String, count: int) -> void:
	var source := model(species).instantiate()
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	for source_mesh in meshes:
		var batch := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = source_mesh.mesh.duplicate()
		for surface in range(mm.mesh.get_surface_count()):
			var original: Material = source_mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				mm.mesh.surface_set_material(surface, wind_material(original))
		mm.instance_count = count
		batch.multimesh = mm
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 48.0
		add_child(batch)
		for i in range(count):
			var p := scatter_point(39.0)
			var path_distance := absf(p.x - 2.4 * sin(p.z * 0.055))
			if path_distance < 2.0 or Vector2(p.x + 12, (p.z + 3) / 1.6).length() < 6.0:
				p.y -= 5.0
			var size := rng.randf_range(0.65, 1.25)
			if "Flower" in species:
				size *= 0.24
			elif "Tall" in species:
				size *= 0.65
			var instance_basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(
				Vector3.ONE * size
			)
			mm.set_instance_transform(i, Transform3D(instance_basis, p))
	source.free()


func landmarks() -> void:
	for i in range(7):
		var angle := float(i) / 7.0 * TAU
		var p := Vector3(5.5 + cos(angle) * 2.5, 0, -7 + sin(angle) * 2.5)
		plant("Rock_Medium_1", p, rng.randf_range(0.4, 0.7))
	for p in [Vector3(0, 0, -2), Vector3(3.2, 0, -5.0), Vector3(-3.6, 0, -7.0)]:
		var target := StaticBody3D.new()
		target.set_script(TARGET)
		target.position = p
		add_child(target)
		targets.append(target)
	# Small carved route markers visually lead into the clearing.
	for z in [10.0, -12.0]:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 1.15, 0.16)
		marker.mesh = box
		marker.position = Vector3(2.9, 0.57, z)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("5b3e29")
		marker.material_override = wood
		add_child(marker)


func toggle_quality() -> void:
	high_quality = not high_quality
	environment.volumetric_fog_enabled = high_quality
	environment.ssao_enabled = high_quality
	environment.ssr_enabled = high_quality
	get_viewport().msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED


func stop_audio() -> void:
	for audio in find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	# Fixed-fps headless tests can outpace the independent audio mixer thread.
	OS.delay_msec(100)
	await get_tree().process_frame
	await get_tree().process_frame


func capture_suite(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(18):
		await get_tree().process_frame
	await save_frame(directory, "01-third-person")
	player.set_first_person(true)
	for i in range(10):
		await get_tree().process_frame
	await save_frame(directory, "02-first-person")
	player.set_first_person(false)
	player.attack()
	for i in range(9):
		await get_tree().process_frame
	await save_frame(directory, "03-sword")
	player.action_timer = 0.0
	for slash in get_tree().get_nodes_in_group("transient_slash"):
		slash.queue_free()
	player.magic_cooldown = 0.0
	player.cast_magic()
	for i in range(12):
		await get_tree().process_frame
	await save_frame(directory, "04-magic")
	player.action_timer = 0.0
	player.velocity.y = 6.0
	for i in range(8):
		await get_tree().process_frame
	await save_frame(directory, "05-jump")
	player.velocity = Vector3.ZERO
	player.position = Vector3(0, 0.05, 7)
	Input.action_press("forward")
	for i in range(8):
		await get_tree().process_frame
	await save_frame(directory, "06-walking")
	Input.action_release("forward")
	player.set_physics_process(false)
	player.play_clip("Sword_Idle")
	player.camera.global_position = Vector3(10, 5.0, 17)
	player.camera.look_at(Vector3(0, 1.5, -1))
	for i in range(3):
		await get_tree().process_frame
	await save_frame(directory, "07-forest-overview")
	print("FOREST_CAPTURE_OK ", directory)
	await stop_audio()
	get_tree().quit(0)


func save_frame(directory: String, model_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := directory.path_join(model_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("FOREST_FRAME ", model_name, " player=", player.position)
