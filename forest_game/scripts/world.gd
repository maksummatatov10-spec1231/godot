extends Node3D
## Deterministic handcrafted clearing, with seeded forest dressing around it.
const PLAYER = preload("res://scripts/player.gd")
const TARGET = preload("res://scripts/target.gd")
const HUD = preload("res://scripts/hud.gd")
const MENU = preload("res://scripts/menu.gd")
const EFFECTS = preload("res://scripts/effects.gd")

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
var profile := 1
var menu: CanvasLayer
var effects: Node3D
var birds: AudioStreamPlayer
var wind: AudioStreamPlayer
var grass_batches: Array[MultiMeshInstance3D] = []
var tree_render_batches: Array[MultiMeshInstance3D] = []
var shadow_atlas_size := 2048


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
	effects = Node3D.new()
	effects.set_script(EFFECTS)
	add_child(effects)
	player.update_camera(1.0, 0)
	menu = CanvasLayer.new()
	menu.set_script(MENU)
	add_child(menu)
	if capture_mode:
		apply_profile(2)
	else:
		prepare_play.call_deferred()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_suite.call_deferred(arg.trim_prefix("--capture-dir="))
	print("FOREST_READY trees=280 ground_cover=3400 seed=730221")


static func height_at(x: float, z: float) -> float:
	var clearing := smoothstep(9.0, 28.0, Vector2(x, z).length())
	return clearing * (sin(x * 0.09) * 1.8 + cos(z * 0.11) * 1.2 + 1.0)


func prepare_play() -> void:
	effects.process_mode = Node.PROCESS_MODE_ALWAYS
	apply_profile(2)
	await effects.warm_up(player.camera)
	effects.process_mode = Node.PROCESS_MODE_INHERIT
	menu.apply_options()
	await get_tree().process_frame
	menu.finish_loading()


func ambient_sound() -> void:
	wind = AudioStreamPlayer.new()
	wind.stream = preload("res://audio/wind.ogg")
	wind.stream.loop = true
	add_child(wind)
	wind.play()
	birds = AudioStreamPlayer.new()
	birds.stream = preload("res://audio/birds.ogg")
	birds.stream.loop = true
	add_child(birds)
	birds.play()


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
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.ssao_enabled = true
	environment.ssao_radius = 1.3
	environment.ssao_intensity = 1.5
	environment.ssr_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("aac5cf")
	environment.fog_density = 0.0007
	environment.fog_sun_scatter = 0.08
	environment.fog_sky_affect = 0.0
	environment.volumetric_fog_sky_affect = 0.0
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0012
	environment.volumetric_fog_albedo = Color("c5d4d0")
	environment.volumetric_fog_length = 75.0
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "LateMorningSun"
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sky_mat.set_shader_parameter("sun_direction", sun.basis.z)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 55.0
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
	var key := species + str(floori(pos.x / 16.0)) + ":" + str(floori(pos.z / 16.0))
	if not tree_batches.has(key):
		tree_batches[key] = {
			"species": species,
			"transforms": [],
			"origin": Vector3(floorf(pos.x / 16.0) * 16 + 8, 0, floorf(pos.z / 16.0) * 16 + 8)
		}
	var orientation := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * size)
	tree_batches[key].transforms.append(Transform3D(orientation, pos - tree_batches[key].origin))
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
	var mesh_cache: Dictionary = {}
	for entry in tree_batches.values():
		var source: Node3D = model(entry.species).instantiate()
		for piece in source.find_children("*", "MeshInstance3D", true, false):
			var batch := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			var key: String = entry.species + ":" + str(piece.mesh.get_rid().get_id())
			if not mesh_cache.has(key):
				var mesh: Mesh = piece.mesh.duplicate()
				for surface in range(mesh.get_surface_count()):
					var original: Material = piece.get_active_material(surface)
					if original is StandardMaterial3D and "Leaves" in original.resource_name:
						mesh.surface_set_material(surface, wind_material(original))
				mesh_cache[key] = mesh
			mm.mesh = mesh_cache[key]
			mm.instance_count = entry.transforms.size()
			for i in range(mm.instance_count):
				mm.set_instance_transform(i, entry.transforms[i] * piece.transform)
			batch.multimesh = mm
			batch.position = entry.origin
			add_child(batch)
			tree_render_batches.append(batch)
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
	var cells: Dictionary = {}
	for i in range(count):
		var p := scatter_point(39.0)
		var path_distance := absf(p.x - 2.4 * sin(p.z * 0.055))
		if path_distance < 2.0 or Vector2(p.x + 12, (p.z + 3) / 1.6).length() < 6.0:
			continue
		var size := rng.randf_range(0.65, 1.25)
		if "Flower" in species:
			size *= 0.24
		elif "Tall" in species:
			size *= 0.38
		else:
			size *= 0.7
		var cell := Vector2i(floori(p.x / 10.0), floori(p.z / 10.0))
		if not cells.has(cell):
			cells[cell] = []
		var origin := Vector3(cell.x * 10 + 5, 0, cell.y * 10 + 5)
		var orientation := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * size)
		cells[cell].append(Transform3D(orientation, p - origin))
	for source_mesh in source.find_children("*", "MeshInstance3D", true, false):
		var shared_mesh: Mesh = source_mesh.mesh.duplicate()
		for surface in range(shared_mesh.get_surface_count()):
			var original: Material = source_mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				shared_mesh.surface_set_material(surface, wind_material(original))
		for cell in cells:
			var batch := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = shared_mesh
			mm.instance_count = cells[cell].size()
			for i in range(mm.instance_count):
				mm.set_instance_transform(i, cells[cell][i])
			batch.multimesh = mm
			batch.visibility_range_end = 38.0
			add_child(batch)
			batch.position = Vector3(cell.x * 10 + 5, 0, cell.y * 10 + 5)
			grass_batches.append(batch)
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
	apply_profile(1 if profile == 2 else 2)
	if menu != null:
		menu.options.profile = profile
		menu.save_options()


func apply_profile(value: int) -> void:
	profile = clampi(value, 0, 2)
	high_quality = profile == 2
	environment.volumetric_fog_enabled = high_quality
	environment.ssao_enabled = profile >= 1
	environment.ssr_enabled = high_quality
	# High keeps foliage/hero shadows and SSAO, without always-on PCSS + 4K atlas
	# and the previous MSAA+FXAA double AA cost. Ultra remains an explicit option.
	get_viewport().msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED
	shadow_atlas_size = 4096 if high_quality else (1024 if profile == 0 else 2048)
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		(
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
			if high_quality
			else RenderingServer.SHADOW_QUALITY_SOFT_LOW
		)
	)
	RenderingServer.environment_set_ssao_quality(
		(
			RenderingServer.ENV_SSAO_QUALITY_MEDIUM
			if high_quality
			else RenderingServer.ENV_SSAO_QUALITY_LOW
		),
		true,
		0.5,
		2,
		35.0,
		65.0
	)
	var sun: DirectionalLight3D = $LateMorningSun
	sun.light_angular_distance = 0.8 if high_quality else 0.0
	sun.directional_shadow_blend_splits = high_quality
	sun.directional_shadow_max_distance = [24.0, 38.0, 55.0][profile]
	sun.directional_shadow_mode = (
		DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		if high_quality
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	)
	for batch in tree_render_batches:
		batch.visibility_range_end = [70.0, 90.0, 110.0][profile]
		batch.lod_bias = [0.5, 0.8, 1.0][profile]
	for batch in grass_batches:
		batch.visibility_range_end = [22.0, 32.0, 42.0][profile]


func set_grass_shadows(enabled: bool) -> void:
	for batch in grass_batches:
		batch.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if enabled
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)


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
	await effects.warm_up(player.camera)
	var pipelines_before: Dictionary = effects.pipeline_counts()
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
	# Let the landing blend finish before documenting the walking cycle.
	for i in range(20):
		await get_tree().process_frame
	await save_frame(directory, "06-walking")
	Input.action_release("forward")
	player.set_physics_process(false)
	player.camera_motion_enabled = false
	player.play_clip("Sword_Idle")
	player.camera.global_position = Vector3(10, 5.0, 17)
	player.camera.look_at(Vector3(0, 1.5, -1))
	for i in range(3):
		await get_tree().process_frame
	await save_frame(directory, "07-forest-overview")
	player.camera_motion_enabled = true
	player.set_physics_process(true)
	player.set_first_person(true)
	player.pitch = -1.15
	for i in range(5):
		await get_tree().process_frame
	await save_frame(directory, "08-fps-body-shadow")
	player.set_first_person(false)
	player.pitch = 0.75
	player.set_first_person(true)
	player.yaw = -2.48
	for i in range(5):
		await get_tree().process_frame
	await save_frame(directory, "09-sky-sun")
	var report := FileAccess.open(directory.path_join("runtime-metrics.json"), FileAccess.WRITE)
	report.store_string(
		JSON.stringify(
			{
				"device": RenderingServer.get_video_adapter_name(),
				"hardware_fps_benchmark": false,
				"pipelines_after_warmup": pipelines_before,
				"pipelines_after_gameplay_captures": effects.pipeline_counts(),
				"vfx_pool_nodes": effects.get_child_count(),
				"grass_chunks": grass_batches.size(),
				"static_ram_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
				"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
			},
			"  "
		)
	)
	menu.started = true
	menu.ready_to_play = true
	menu.show_main()
	await save_frame(directory, "10-pause-menu")
	menu.show_graphics()
	await save_frame(directory, "11-graphics-settings")
	menu.show_audio()
	await save_frame(directory, "12-audio-settings")
	menu.main_menu()
	await save_frame(directory, "13-main-menu")
	menu.show_controls()
	await save_frame(directory, "14-controls-settings")
	get_tree().paused = false
	menu.visible = false
	player.set_physics_process(false)
	player.set_process(false)
	player.yaw = 0
	player.pitch = -0.09
	player.current_clip = ""
	player.play_clip("Sword_Idle")
	player.animator.play("Sword_Idle", 0)
	player.animator.seek(0.3, true)
	player.advance_animation(0)
	player.set_first_person(false)
	var hand: Transform3D = (
		player.skeleton.global_transform
		* player.skeleton.get_bone_global_pose(player.skeleton.find_bone("hand_r"))
	)
	player.camera.global_position = hand.origin + Vector3(0.28, 0.14, 0.27)
	player.camera.look_at(hand.origin)
	for i in range(3):
		await get_tree().process_frame
	await save_frame(directory, "15-grip-close")
	player.set_first_person(true)
	player.update_camera(1.0, 0)
	var clips := [
		"Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Walk", "Jump", "Jump_Land"
	]
	for index in range(clips.size()):
		var clip: String = clips[index]
		player.current_clip = ""
		player.play_clip(clip)
		player.animator.play(clip, 0)
		player.animator.seek(0.3, true)
		for i in range(3):
			player.advance_animation(0)
			await get_tree().process_frame
		await save_frame(directory, "%02d-fps-%s" % [16 + index, clip.to_lower()])
	apply_profile(1)
	player.current_clip = ""
	player.play_clip("Sword_Idle")
	player.set_process(true)
	for i in range(4):
		await get_tree().process_frame
	await save_frame(directory, "22-high-optimized")
	var diagnostic := Node.new()
	diagnostic.set_script(preload("res://scripts/performance_diagnostic.gd"))
	add_child(diagnostic)
	var measurements: Dictionary = await diagnostic.run(
		self, directory.path_join("performance-ab.json"), true
	)
	assert(measurements.stages.size() == 12)
	diagnostic.queue_free()
	print("FOREST_CAPTURE_OK ", directory)
	await stop_audio()
	get_tree().quit(0)


func save_frame(directory: String, model_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := directory.path_join(model_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("FOREST_FRAME ", model_name, " player=", player.position)
