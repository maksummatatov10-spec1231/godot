extends Node3D
## Real-device integration fixture. Never reports GPU success in headless mode.

var frames := 0
var capture_path := ""
var cloud_effect: SunshineCloudsGD
var cloud_world: WorldEnvironment
var cloud_driver: SunshineCloudsDriverGD


func _ready() -> void:
	if RenderingServer.get_rendering_device() == null:
		push_error(
			"Forward+ needs a working Vulkan/D3D12/Metal device. Headless is not a GPU test."
		)
		get_tree().quit(1)
		return
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Forward+ required; refusing a degraded renderer fallback.")
		get_tree().quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")

	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_SKY
	world.environment.sky = Sky.new()
	world.environment.sky.sky_material = ProceduralSkyMaterial.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25.0, -35.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	if not OS.get_cmdline_user_args().has("--without-terrain"):
		print("RENDER_STAGE terrain")
		var terrain := ClassDB.instantiate("Terrain3D") as Node3D
		terrain.name = "Terrain3D"
		terrain.set("free_editor_textures", false)
		terrain.set("tessellation_level", 0)
		# Exercise the vendor's optimized material with actual texture layers,
		# not an empty texture array in the heavyweight default shader.
		var material := ClassDB.instantiate("Terrain3DMaterial") as Resource
		material.set(
			"shader_override", load("res://addons/terrain_3d/extras/shaders/lightweight.gdshader")
		)
		material.set("shader_override_enabled", true)
		terrain.set("material", material)
		var assets := ClassDB.instantiate("Terrain3DAssets") as Resource
		var texture_asset := ClassDB.instantiate("Terrain3DTextureAsset") as Resource
		var albedo := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		albedo.fill(Color(0.24, 0.38, 0.16, 1.0))
		albedo.generate_mipmaps()
		texture_asset.set("albedo_texture", ImageTexture.create_from_image(albedo))
		var normal := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		normal.fill(Color(0.5, 0.5, 1.0, 1.0))
		normal.generate_mipmaps()
		texture_asset.set("normal_texture", ImageTexture.create_from_image(normal))
		assets.set("texture_list", [texture_asset])
		terrain.set("assets", assets)
		add_child(terrain)
		terrain.get("data").call("add_region_blank", Vector2i.ZERO)

	var camera := Camera3D.new()
	camera.position = Vector3(128.0, 12.0, 100.0)
	camera.far = 100000.0
	add_child(camera)
	camera.look_at(Vector3(128.0, 25.0, 300.0))
	camera.current = true

	if not OS.get_cmdline_user_args().has("--without-clouds"):
		print("RENDER_STAGE clouds")
		var clouds := load("res://resources/clouds_balanced.tres") as SunshineCloudsGD
		world.compositor = Compositor.new()
		world.compositor.compositor_effects = [clouds]
		var driver := SunshineCloudsDriverGD.new()
		driver.clouds_resource = clouds
		driver.ambience_sample_environment = world.environment
		driver.tracked_directional_lights = [sun]
		driver.tracked_directional_light_shadow_steps = [8]
		driver.update_continuously = true
		add_child(driver)
		driver.retrieve_texture_data()
		cloud_effect = clouds
		cloud_world = world
		cloud_driver = driver

	print("RENDER_STAGE hud")
	var hud := CanvasLayer.new()
	add_child(hud)
	var label := Label.new()
	label.position = Vector2(20.0, 20.0)
	label.text = (
		"Forward+ / "
		+ (
			"Sky"
			if OS.get_cmdline_user_args().has("--without-terrain")
			else "Terrain3D lightweight"
		)
		+ " / "
		+ ("No clouds" if OS.get_cmdline_user_args().has("--without-clouds") else "SunshineClouds2")
		+ "\n"
		+ "Balanced clouds: quarter resolution, 64 view steps, 8 lighting steps\n"
		+ RenderingServer.get_rendering_device().get_device_name()
	)
	hud.add_child(label)


func _process(_delta: float) -> void:
	if capture_path.is_empty():
		return
	frames += 1
	if frames < 60:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(capture_path) != OK:
		push_error("Cannot save the rendered validation frame")
		get_tree().quit(1)
		return
	print("RENDER_VALIDATION_OK ", capture_path)
	# Drain cloud RD work before RenderingServer shutdown, not after finalization.
	if cloud_effect != null:
		cloud_driver.update_continuously = false
		cloud_effect.enabled = false
		cloud_world.compositor.compositor_effects = []
		RenderingServer.call_on_render_thread(cloud_effect.clear_compute)
		await get_tree().process_frame
		await get_tree().process_frame
	get_tree().quit(0)
