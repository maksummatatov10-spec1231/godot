extends CanvasLayer

const BENCHMARK = preload("res://scripts/benchmark.gd")
## Actual pause/main/settings screens; UI runs while world physics is paused.
var world: Node3D
var panel: PanelContainer
var content: VBoxContainer
var title: Label
var loading: Label
var screen := "main"
var started := false
var ready_to_play := false
var config := ConfigFile.new()
var options := {
	"profile": 1,
	"scale": 1.0,
	"grass_shadows": true,
	"vsync": true,
	"fullscreen": false,
	"birds": true,
	"wind": 0.65,
	"sfx": 0.8,
	"sensitivity": 1.0,
	"invert_y": false,
	"fps": false,
	"limit": 60,
	"resolution": 0
}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	if not world.capture_mode and config.load("user://settings.cfg") == OK:
		for key in options:
			options[key] = config.get_value("options", key, options[key])
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.035, 0.044, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172a2c")
	style.border_color = Color("607e70")
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	apply_options()
	show_main()
	if world.capture_mode:
		visible = false
		started = true
		ready_to_play = true
	else:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func clear(heading: String) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	title = Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("e6d9b4"))
	content.add_child(title)


func button(caption: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = caption
	item.custom_minimum_size.y = 42
	item.pressed.connect(action)
	content.add_child(item)
	return item


func show_main() -> void:
	screen = "pause" if started else "main"
	visible = true
	clear("ПАУЗА" if started else "WARDEN · ИЗУМРУДНЫЙ ЛЕС")
	var subtitle := Label.new()
	subtitle.text = "Тренировочная поляна • меч и огненная магия"
	content.add_child(subtitle)
	var play := button("Продолжить" if started else "Начать игру", resume)
	play.disabled = not ready_to_play
	button("Настройки", show_settings)
	if started:
		button("Главное меню", main_menu)
	button("Выйти из игры", func(): get_tree().quit())
	loading = Label.new()
	loading.text = (
		"Подготовка эффектов и шейдеров…"
		if not ready_to_play
		else "WASD · Shift · Space · V камера · ЛКМ меч · Q магия · Esc пауза"
	)
	loading.add_theme_font_size_override("font_size", 13)
	content.add_child(loading)


func finish_loading() -> void:
	ready_to_play = true
	if screen == "main":
		show_main()


func resume() -> void:
	if not ready_to_play:
		return
	started = true
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world.player.camera_initialized = false


func main_menu() -> void:
	started = false
	get_tree().paused = true
	show_main()


func pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_main()


func _unhandled_input(event: InputEvent) -> void:
	if world.capture_mode:
		return
	if event.is_action_pressed("ui_cancel"):
		if visible and screen in ["settings", "graphics", "audio", "controls"]:
			show_main()
		elif visible and started:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func show_settings() -> void:
	screen = "settings"
	clear("НАСТРОЙКИ")
	button("Графика и экран", show_graphics)
	button("Звук и окружение", show_audio)
	button("Управление", show_controls)
	button("Назад", show_main)


func toggle(caption: String, key: String) -> void:
	var item := CheckButton.new()
	item.text = caption
	item.button_pressed = options[key]
	item.toggled.connect(
		func(value: bool):
			options[key] = value
			save_options()
	)
	content.add_child(item)


func slider(caption: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 300
	row.add_child(label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 55
	value_label.text = str(options[key])
	var item := HSlider.new()
	item.custom_minimum_size = Vector2(150, 28)
	item.min_value = low
	item.max_value = high
	item.step = step
	item.value = options[key]
	item.value_changed.connect(
		func(value: float):
			options[key] = value
			value_label.text = str(value)
			save_options()
	)
	row.add_child(item)
	row.add_child(value_label)
	content.add_child(row)


func show_graphics() -> void:
	screen = "graphics"
	clear("ГРАФИКА И ЭКРАН")
	var presets := OptionButton.new()
	for caption in [
		"Низкий — максимум запаса",
		"Высокий — начать с него на RX 580",
		"Ультра — более дорогой туман и отражения"
	]:
		presets.add_item(caption)
	presets.selected = int(options.profile)
	presets.item_selected.connect(
		func(index: int):
			options.profile = index
			save_options()
	)
	content.add_child(presets)
	var resolution := OptionButton.new()
	for caption in ["1280 × 720", "1600 × 900", "1920 × 1080"]:
		resolution.add_item(caption)
	resolution.selected = int(options.resolution)
	resolution.item_selected.connect(
		func(index: int):
			options.resolution = index
			save_options()
	)
	content.add_child(resolution)
	slider("Масштаб 3D (UI остаётся чётким)", "scale", 0.5, 1.0, 0.05)
	slider("Ограничение FPS (0 — без лимита)", "limit", 0, 144, 1)
	toggle("Тени от травы", "grass_shadows")
	toggle("Вертикальная синхронизация", "vsync")
	toggle("Полноэкранный режим", "fullscreen")
	toggle("Показывать FPS и время кадра", "fps")
	button("Проверить производительность на моём ПК (22 сек.)", run_benchmark)
	button("Назад", show_settings)


func run_benchmark() -> void:
	if not ready_to_play:
		return
	var benchmark := Node.new()
	benchmark.set_script(BENCHMARK)
	world.add_child(benchmark)
	benchmark.start(world)


func show_audio() -> void:
	screen = "audio"
	clear("ЗВУК И ОКРУЖЕНИЕ")
	toggle("Пение птиц (отдельно от ветра)", "birds")
	slider("Ветер и атмосфера", "wind", 0, 1, 0.05)
	slider("Шаги, меч и магия", "sfx", 0, 1, 0.05)
	button("Назад", show_settings)


func show_controls() -> void:
	screen = "controls"
	clear("УПРАВЛЕНИЕ")
	slider("Чувствительность мыши", "sensitivity", 0.2, 3, 0.1)
	toggle("Инвертировать вертикальный обзор", "invert_y")
	var help := Label.new()
	help.text = (
		"WASD — движение · Shift — бег в ОБЕИХ камерах\n"
		+ "Space — прыжок · V — камера · ПКМ — прицел\n"
		+ "ЛКМ — меч · Q — магия · Esc — пауза"
	)
	content.add_child(help)
	button("Назад", show_settings)


func save_options() -> void:
	apply_options()
	if world.capture_mode:
		return
	for key in options:
		config.set_value("options", key, options[key])
	config.save("user://settings.cfg")


func apply_options() -> void:
	world.apply_profile(int(options.profile))
	get_viewport().scaling_3d_scale = float(options.scale)
	Engine.max_fps = int(options.limit) if not world.capture_mode else 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if options.vsync else DisplayServer.VSYNC_DISABLED
		)
		if not world.capture_mode:
			DisplayServer.window_set_size(
				[Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)][clampi(
					int(options.resolution), 0, 2
				)]
			)
			DisplayServer.window_set_mode(
				(
					DisplayServer.WINDOW_MODE_FULLSCREEN
					if options.fullscreen
					else DisplayServer.WINDOW_MODE_WINDOWED
				)
			)
	world.set_grass_shadows(options.grass_shadows)
	world.birds.volume_db = -12 if options.birds else -80
	world.wind.volume_db = linear_to_db(maxf(0.0001, float(options.wind)))
	world.player.mouse_sensitivity = 0.0022 * float(options.sensitivity)
	world.player.invert_y = options.invert_y
	for sound in world.player.sounds.values():
		sound.volume_db = linear_to_db(maxf(0.0001, float(options.sfx))) - 14
