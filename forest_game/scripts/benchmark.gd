extends Node
## On-device measurement, not a predicted RX 580 FPS claim. No fixed-fps mode.
var world: Node3D
var frames: Array[float] = []
var elapsed := 0.0
var next_cast := 0.5
var path := "user://benchmark.json"
var active := false
var saved_yaw := 0.0
var saved_pitch := 0.0
var gpu_total := 0.0
var cpu_total := 0.0
var animation_total := 0.0


func start(scene_world: Node3D) -> void:
	world = scene_world
	world.menu.resume()
	saved_yaw = world.player.yaw
	saved_pitch = world.player.pitch
	world.player.input_enabled = false
	world.player.position = Vector3(0, 0.05, 7)
	world.player.reset_physics_interpolation()
	world.player.yaw = 0
	world.player.pitch = -0.09
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	active = true


func _process(delta: float) -> void:
	if not active:
		return
	if get_tree().paused:
		return
	elapsed += delta
	# Discard 2 seconds of transition/warmup; then measure real delivered frame intervals.
	if elapsed > 2:
		frames.append(delta * 1000.0)
		gpu_total += RenderingServer.viewport_get_measured_render_time_gpu(
			get_viewport().get_viewport_rid()
		)
		cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(
			get_viewport().get_viewport_rid()
		)
		animation_total += world.player.animation_cpu_usec
	world.player.yaw = sin(elapsed * 0.35) * 0.55
	if elapsed >= next_cast:
		next_cast += 3.0
		world.player.action_timer = 0
		world.player.magic_cooldown = 0
		world.player.cast_magic()
	if elapsed > 22:
		finish()


func finish() -> void:
	active = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
	world.player.input_enabled = true
	world.player.yaw = saved_yaw
	world.player.pitch = saved_pitch
	frames.sort()
	if frames.is_empty():
		queue_free()
		return
	var total := 0.0
	for frame in frames:
		total += frame
	var average := total / frames.size()
	var p99 := frames[mini(frames.size() - 1, int(frames.size() * 0.99))]
	var report := {
		"device": RenderingServer.get_video_adapter_name(),
		"cpu": OS.get_processor_name(),
		"resolution": DisplayServer.window_get_size(),
		"render_target": get_viewport().get_texture().get_size(),
		"first_person": world.player.first_person,
		"gpu_ms": gpu_total / frames.size(),
		"render_thread_cpu_ms": cpu_total / frames.size(),
		"animation_cpu_us": animation_total / frames.size(),
		"gpu_timer_available": gpu_total > 0,
		"profile": world.profile,
		"render_scale": get_viewport().scaling_3d_scale,
		"frames": frames.size(),
		"average_fps": 1000.0 / average,
		"average_ms": average,
		"p99_ms": p99,
		"worst_ms": frames.back(),
		"static_ram_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"note":
		"Uncapped on-device 20-second orbit + repeated magic. Not a universal performance guarantee."
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	world.menu.apply_options()
	world.menu.pause()
	world.menu.clear("РЕЗУЛЬТАТ ТЕСТА")
	var result := Label.new()
	result.text = (
		"Средний FPS: %.1f\nСредний кадр: %.1f мс · p99: %.1f мс\nХудший кадр: %.1f мс\n"
		% [1000 / average, average, p99, frames.back()]
	)
	result.text += (
		"Тест: текущие настройки, вращение камеры и магия.\n"
		+ "Отчёт сохранён в user://benchmark.json"
	)
	world.menu.content.add_child(result)
	world.menu.button("Открыть папку отчёта", func(): OS.shell_open(OS.get_user_data_dir()))
	world.menu.button("Назад", world.menu.show_main)
	queue_free()
