extends Node
## Fixed-view A/B ablations. Real wall-clock intervals, never Engine fixed delta.
## Software-renderer CI evidence is NOT an RX 580 benchmark.
const VARIANTS = [
	"baseline",
	"legacy_high",
	"legacy_no_pcss",
	"legacy_no_msaa",
	"half_resolution",
	"no_post",
	"no_shadows",
	"no_trees",
	"no_grass",
	"frozen_animation",
	"no_vfx",
	"baseline_repeat"
]

var cancelled := false
var progress: Label
var running := false


func apply_variant(world: Node3D, variant: String, state: Dictionary) -> void:
	world.apply_profile(state.profile)
	var viewport := world.get_viewport()
	viewport.scaling_3d_scale = state.scale
	var sun: DirectionalLight3D = world.get_node("LateMorningSun")
	sun.shadow_enabled = state.shadows
	for i in range(world.tree_render_batches.size()):
		world.tree_render_batches[i].visible = state.trees[i]
	for i in range(world.grass_batches.size()):
		world.grass_batches[i].visible = state.grass[i]
	world.effects.visible = state.effects_visible
	world.effects.process_mode = state.effects_process
	world.player.set_process(state.player_process)
	world.player.arm_modifier.active = world.player.first_person
	if world.player.first_person:
		world.player.sync_first_person_pose()
	if variant.begins_with("legacy_"):
		# Exact expensive High stack used by v0.2/v0.3, same view/resolution.
		world.apply_profile(1)
		world.shadow_atlas_size = 4096
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
		)
		RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0
		)
		sun.light_angular_distance = 0.8
		sun.directional_shadow_blend_splits = true
		viewport.msaa_3d = Viewport.MSAA_2X
		if variant == "legacy_no_pcss":
			sun.light_angular_distance = 0.0
		if variant == "legacy_no_msaa":
			viewport.msaa_3d = Viewport.MSAA_DISABLED
	match variant:
		"half_resolution":
			viewport.scaling_3d_scale = state.scale * 0.5
		"no_post":
			world.environment.ssao_enabled = false
			world.environment.ssr_enabled = false
			world.environment.glow_enabled = false
			world.environment.volumetric_fog_enabled = false
		"no_shadows":
			sun.shadow_enabled = false
		"no_trees":
			for batch in world.tree_render_batches:
				batch.visible = false
		"no_grass":
			for batch in world.grass_batches:
				batch.visible = false
		"frozen_animation":
			world.player.set_process(false)
			world.player.arm_modifier.active = false
		"no_vfx":
			world.effects.visible = false
			world.effects.process_mode = Node.PROCESS_MODE_DISABLED


func run(
	world: Node3D, output := "user://performance-diagnostic.json", frame_mode := false
) -> Dictionary:
	if running:
		return {}
	running = true
	add_to_group("performance_diagnostic")
	var viewport := world.get_viewport()
	var player: CharacterBody3D = world.player
	var state := {
		"profile": world.profile,
		"scale": viewport.scaling_3d_scale,
		"shadows": world.get_node("LateMorningSun").shadow_enabled,
		"trees": [],
		"grass": [],
		"effects_visible": world.effects.visible,
		"effects_process": world.effects.process_mode,
		"player_process": player.is_processing(),
		"physics": player.is_physics_processing(),
		"input": player.input_enabled,
		"transform": player.transform,
		"velocity": player.velocity,
		"yaw": player.yaw,
		"pitch": player.pitch,
		"paused": get_tree().paused,
		"menu_visible": world.menu.visible,
		"limit": Engine.max_fps,
		"vsync": DisplayServer.window_get_vsync_mode(),
		"glow": world.environment.glow_enabled
	}
	for batch in world.tree_render_batches:
		state.trees.append(batch.visible)
	for batch in world.grass_batches:
		state.grass.append(batch.visible)
	player.input_enabled = false
	player.set_physics_process(false)
	player.position = Vector3(0, world.height_at(0, 7) + 0.1, 7)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.yaw = 0
	player.pitch = -0.09
	player.update_camera(1, 0)
	get_tree().paused = false
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	if not frame_mode:
		world.menu.visible = true
		world.menu.clear("ДИАГНОСТИКА ПРОИЗВОДИТЕЛЬНОСТИ")
		progress = Label.new()
		world.menu.content.add_child(progress)
		world.menu.button("Отменить и восстановить настройки", func(): cancelled = true)
	var report := {
		"device": RenderingServer.get_video_adapter_name(),
		"vendor": RenderingServer.get_video_adapter_vendor(),
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"render_target": viewport.get_texture().get_size(),
		"engine": Engine.get_version_info().string,
		"viewport": viewport.get_visible_rect().size,
		"window": DisplayServer.window_get_size(),
		"profile": state.profile,
		"render_scale": state.scale,
		"first_person": player.first_person,
		"source_revision": "v0.3.1",
		"ci_frame_mode": frame_mode,
		"note":
		(
			"Fixed-camera, uncapped A/B ablations. No claim about untested hardware. "
			+ "Legacy stages reconstruct old High GPU settings, not the old executable."
		),
		"stages": []
	}
	for variant in VARIANTS:
		if cancelled:
			break
		world.environment.glow_enabled = state.glow
		apply_variant(world, variant, state)
		if is_instance_valid(progress):
			progress.text = (
				"%d / %d: %s\nКамера фиксирована. Настройки будут восстановлены."
				% [report.stages.size() + 1, VARIANTS.size(), variant]
			)
		var samples: Array[float] = []
		var cpu := 0.0
		var gpu := 0.0
		var animation := 0.0
		var draws := 0.0
		var primitives := 0.0
		var warm_frames := 0
		var start := Time.get_ticks_usec()
		while not cancelled:
			await RenderingServer.frame_post_draw
			warm_frames += 1
			if (
				(frame_mode and warm_frames >= 6)
				or (not frame_mode and Time.get_ticks_usec() - start >= 1_200_000)
			):
				break
		var previous := Time.get_ticks_usec()
		start = previous
		while not cancelled:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			samples.append((now - previous) / 1000.0)
			previous = now
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(
				viewport.get_viewport_rid()
			)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(
				viewport.get_viewport_rid()
			)
			animation += player.animation_cpu_usec if player.is_processing() else 0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			if (
				(frame_mode and samples.size() >= 8)
				or (not frame_mode and now - start >= 2_800_000)
			):
				break
		if not samples.is_empty():
			var count := samples.size()
			var mean := 0.0
			for sample in samples:
				mean += sample / count
			samples.sort()
			report.stages.append(
				{
					"variant": variant,
					"frames": count,
					"mean_frame_ms": mean,
					"average_fps": 1000.0 / maxf(mean, 0.0001),
					"p99_ms": samples[mini(count - 1, int(count * 0.99))],
					"render_thread_cpu_ms": cpu / count,
					"gpu_ms": gpu / count,
					"gpu_timer_available": gpu > 0,
					"animation_cpu_us": animation / count,
					"draw_calls": draws / count,
					"primitives": primitives / count
				}
			)
			print("PERFORMANCE_STAGE ", JSON.stringify(report.stages.back()))
	world.environment.glow_enabled = state.glow
	apply_variant(world, "baseline", state)
	player.transform = state.transform
	player.velocity = state.velocity
	player.yaw = state.yaw
	player.pitch = state.pitch
	player.input_enabled = state.input
	player.set_physics_process(state.physics)
	player.reset_physics_interpolation()
	player.update_camera(1, 0)
	Engine.max_fps = state.limit
	DisplayServer.window_set_vsync_mode(state.vsync)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
	get_tree().paused = state.paused
	world.menu.visible = state.menu_visible
	report["cancelled"] = cancelled
	report["analysis"] = summarize(report.stages)
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	remove_from_group("performance_diagnostic")
	running = false
	if not frame_mode:
		world.menu.pause()
		world.menu.clear("ДИАГНОСТИКА СОХРАНЕНА" if not cancelled else "ТЕСТ ОТМЕНЁН")
		var label := Label.new()
		label.text = (
			str(report.analysis.message)
			+ "\n"
			+ "Настройки и камера восстановлены.\n"
			+ "Отчёт: user://performance-diagnostic.json\n"
			+ "Пришлите JSON для разбора именно вашего ПК."
		)
		world.menu.content.add_child(label)
		world.menu.button("Открыть папку отчёта", func(): OS.shell_open(OS.get_user_data_dir()))
		world.menu.button("Назад", world.menu.show_main)
	return report


static func summarize(stages: Array) -> Dictionary:
	if stages.is_empty():
		return {"message": "Нет данных", "candidates": [], "stable": false}
	var baseline: float = stages[0].mean_frame_ms
	var repeat_ms := baseline
	var candidates: Array[Dictionary] = []
	var labels := {
		"no_shadows": "Тени",
		"no_post": "Постэффекты",
		"half_resolution": "Заполнение GPU",
		"no_trees": "Деревья",
		"no_grass": "Трава",
		"frozen_animation": "Анимация",
		"no_vfx": "VFX"
	}
	for stage in stages:
		if stage.variant == "baseline_repeat":
			repeat_ms = stage.mean_frame_ms
		if labels.has(stage.variant):
			var saving: float = 1.0 - stage.mean_frame_ms / maxf(baseline, 0.001)
			if saving > 0.10:
				candidates.append({"name": labels[stage.variant], "frame_time_saving": saving})
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary): return a.frame_time_saving > b.frame_time_saving
	)
	var stable := absf(repeat_ms / maxf(baseline, 0.001) - 1.0) < 0.15
	var message := "База: %.1f FPS. " % (1000.0 / maxf(baseline, 0.001))
	if not stable:
		message += "Большие колебания: повторите тест без фоновых задач."
	elif candidates.is_empty():
		message += "Явного одного ограничения нет; нужен разбор JSON."
	else:
		message += "Кандидат на ограничение: " + str(candidates[0].name) + "."
	return {"message": message, "candidates": candidates, "stable": stable}
