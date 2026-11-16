extends Node
# gdlint: disable=max-line-length
## One shared game; physical display/render budgets differ by platform.
const CAPS = [30, 60, 75, 90, 120]
const RESOLUTIONS = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
var world: Node2D
var mobile := false
var auto_run := false
var frame_cap := 75
var vsync := false
var economical := false
var resolution := Vector2i(1920, 1080)
var show_touch := false


func setup(owner_world: Node2D) -> void:
	world = owner_world
	mobile = OS.has_feature("android") or OS.has_feature("android_profile")
	mobile = mobile or ProjectSettings.get_setting("lantern/platform", "pc") == "android"
	frame_cap = 60 if mobile else 75
	vsync = mobile
	economical = mobile
	var config: ConfigFile = world.settings
	auto_run = read_bool(config, "auto_run", false)
	show_touch = read_bool(config, "show_touch", false)
	vsync = read_bool(config, "vsync_mobile" if mobile else "vsync_pc", vsync)
	economical = read_bool(config, "economical", economical)
	var cap: Variant = config.get_value("platform", "cap_mobile" if mobile else "cap_pc", frame_cap)
	if cap is int and cap in CAPS:
		frame_cap = cap
	var dimensions: Variant = config.get_value("platform", "resolution", resolution)
	if dimensions is Vector2i and dimensions in RESOLUTIONS:
		resolution = dimensions
	apply_profile()


func read_bool(config: ConfigFile, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value("platform", key, fallback)
	return value if value is bool else fallback


func apply_profile() -> void:
	if world.capture_running:
		return
	Engine.max_fps = frame_cap
	var window := get_tree().root
	window.content_scale_size = Vector2i(640, 360)
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_mode = (
		Window.CONTENT_SCALE_MODE_VIEWPORT
		if mobile and economical
		else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
		)
		if not mobile and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(resolution)
			var available := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(
				available.position + Vector2i(Vector2(available.size - resolution) * 0.5)
			)


func persist() -> void:
	if world.capture_running:
		return
	var config: ConfigFile = world.settings
	config.set_value("platform", "auto_run", auto_run)
	config.set_value("platform", "show_touch", show_touch)
	config.set_value("platform", "cap_mobile" if mobile else "cap_pc", frame_cap)
	config.set_value("platform", "vsync_mobile" if mobile else "vsync_pc", vsync)
	config.set_value("platform", "economical", economical)
	config.set_value("platform", "resolution", resolution)
	world._save_settings()


func choice(box: VBoxContainer, title: String, labels: Array, index: int, action: Callable) -> void:
	box.add_child(world._label(title, 11, Color("c9c6b8")))
	var select := OptionButton.new()
	select.custom_minimum_size = Vector2(258, 29)
	select.add_theme_font_size_override("font_size", 12)
	for label in labels:
		select.add_item(label)
	select.select(index)
	select.item_selected.connect(action)
	box.add_child(select)


func toggle(box: VBoxContainer, title: String, value: bool, action: Callable) -> CheckButton:
	var button := CheckButton.new()
	button.text = title
	button.add_theme_font_size_override("font_size", 12)
	button.button_pressed = value
	button.toggled.connect(action)
	box.add_child(button)
	return button


func show_settings() -> void:
	world.foundation._clear()
	world.mode = "platform_settings"
	world.touch_controls.release_all()
	world.foundation._shade()
	var title: Label = world._label("ЭКРАН И УПРАВЛЕНИЕ", 18, Color("e4bf7f"))
	title.position = Vector2(28, 22)
	world.menu_root.add_child(title)
	var left := VBoxContainer.new()
	left.position = Vector2(28, 65)
	left.add_theme_constant_override("separation", 8)
	world.menu_root.add_child(left)
	if not mobile:
		choice(
			left,
			"Размер окна · пиксельный мир 640 × 360",
			["1280 × 720", "1600 × 900", "1920 × 1080 · Full HD"],
			RESOLUTIONS.find(resolution),
			func(index: int):
				resolution = RESOLUTIONS[index]
				apply_profile()
				persist()
		)
	else:
		choice(
			left,
			"Рендер · экран всегда альбомный",
			["Ретро · 360p · экономно", "Чётко · родное разрешение"],
			0 if economical else 1,
			func(index: int):
				economical = index == 0
				apply_profile()
				persist()
		)
	choice(
		left,
		"Целевой предел кадров (не гарантия FPS)",
		["30", "60", "75", "90", "120"],
		CAPS.find(frame_cap),
		func(index: int):
			frame_cap = CAPS[index]
			apply_profile()
			persist()
	)
	toggle(
		left,
		"VSync · частота экрана",
		vsync,
		func(value: bool):
			vsync = value
			apply_profile()
			persist()
	)
	if not mobile:
		left.add_child(world._make_button("Окно / полный экран", world._toggle_fullscreen))
	left.add_child(
		world._label(
			"75 FPS требуют подходящего экрана\nи достаточной мощности устройства.",
			10,
			Color("a6b8b4")
		)
	)
	var right := VBoxContainer.new()
	right.position = Vector2(350, 65)
	right.add_theme_constant_override("separation", 10)
	world.menu_root.add_child(right)
	var first := toggle(
		right,
		"Автобег",
		auto_run,
		func(value: bool):
			auto_run = value
			persist()
	)
	(
		right
		. add_child(
			(
				world
				. _label(
					"Включён: движение сразу с бегом.\nВыключен: ходьба; на ПК Shift — бег.\nОтпускание стика всегда останавливает.",
					11,
					Color("a6b8b4")
				)
			)
		)
	)
	if not mobile:
		toggle(
			right,
			"Показать сенсорные кнопки",
			show_touch,
			func(value: bool):
				show_touch = value
				persist()
		)
	right.add_child(world._make_button("Расположение и размер", world.touch_controls.begin_edit))
	(
		right
		. add_child(
			(
				world
				. _label(
					"Стик — любое направление\nZ — действие / далее\nX — взмах / весь текст\nC — меню · L — свет · Q — предмет",
					11,
					Color("a6b8b4")
				)
			)
		)
	)
	var back: Button = world._make_button("Назад", close_settings)
	back.position = Vector2(28, 310)
	world.menu_root.add_child(back)
	first.grab_focus()


func close_settings() -> void:
	world.show_menu("settings")
