extends Node
# gdlint: disable=max-public-methods,max-line-length
## Menus/story, durable state and one screen-space time grade. World simulation stays separate.
const STORY_ART = [
	preload("res://assets/story/01-arrival.png"),
	preload("res://assets/story/02-bell.png"),
	preload("res://assets/story/03-letter.png"),
	preload("res://assets/story/04-first-light.png")
]
const Clock = preload("res://scripts/day_clock.gd")
const Store = preload("res://scripts/save_store.gd")
const STORY = [
	[
		"ДОЛИНА НА РАССВЕТЕ",
		"Перед рассветом ты спускаешься в долину.\nКогда-то её огни встречали рыбаков и провожали путников через лес."
	],
	[
		"ПОСЛЕДНИЙ КОЛОКОЛ",
		"На площади тихо. Здесь колокол прозвучал в последний раз.\nС тех пор люди забывают имена тех, кого ждут домой."
	],
	[
		"СВЕТ, КОТОРЫЙ ОСТАЛСЯ",
		"У двери фонарщика ты находишь письмо: «Не дай тропам погаснуть».\nОн ушёл искать причину — и не вернулся."
	],
	[
		"ТВОЯ ДОРОГА",
		"Ты подносишь свой фонарь к первому огню. День начинается.\nНайди Странника на площади — возможно, он ещё помнит причину."
	]
]
var world: Node2D
var clock := Clock.new()
var store := Store.new()
var session_started := false
var intro_done := false
var play_seconds := 0.0
var autosave_seconds := 120
var autosave_clock := 0.0
var notice: Label
var notice_time := 0.0
var grade_material: ShaderMaterial
var moon: Control
var story_page := 0
var story_clock := 0.0
var story_text: RichTextLabel
var replaying := false
var confirm_action := Callable()
var confirm_return := "main"
var disabled_io := false
var cached_save := {}
var decor: Array[Dictionary] = []
var lights_enabled := true


func setup(owner_world: Node2D) -> void:
	world = owner_world
	disabled_io = world.capture_running
	if disabled_io:
		clock.hour = 12.0
		clock.enabled = false
	else:
		cached_save = store.load_game()
	autosave_seconds = int(world.settings.get_value("save", "interval", 120))
	if autosave_seconds not in [0, 60, 120, 300, 600]:
		autosave_seconds = 120
	clock.cycle_minutes = clampf(float(world.settings.get_value("time", "minutes", 24.0)), 6, 60)
	clock.enabled = not disabled_io and bool(world.settings.get_value("time", "enabled", true))
	var layer := CanvasLayer.new()
	layer.layer = 2
	world.ui.layer = 5
	world.add_child(layer)
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_material = ShaderMaterial.new()
	grade_material.shader = preload("res://scripts/daylight.gdshader")
	grade.material = grade_material
	layer.add_child(grade)
	notice = world._label("", 11, Color("fff0bc"))
	notice.position = Vector2(18, 332)
	world.ui.add_child(notice)
	moon = Control.new()
	moon.set_script(preload("res://scripts/moon.gd"))
	moon.set("foundation", self)
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.ui.add_child(moon)
	for sprite in world.actors.get_children():
		if sprite is Sprite2D and sprite.get_meta("art", "") == "well.png":
			decor.append({"sprite": sprite, "width": 32.0, "height": 32.0})
	get_tree().auto_accept_quit = false


func _process(delta: float) -> void:
	if world == null:
		return
	if world.mode == "play":
		clock.advance(delta)
		play_seconds += delta
		if session_started and not disabled_io and autosave_seconds > 0:
			autosave_clock += delta
			if autosave_clock >= autosave_seconds:
				autosave_clock = 0
				save_game(true)
	if world.mode == "intro" and is_instance_valid(story_text):
		story_clock += delta * 30.0
		story_text.visible_characters = int(story_clock)
	notice_time = maxf(0, notice_time - delta)
	notice.visible = notice_time > 0
	_update_lighting()


func _update_lighting() -> void:
	var rect: Rect2 = world.world_view_rect()
	grade_material.set_shader_parameter(
		"world_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	)
	grade_material.set_shader_parameter("grade", clock.tint())
	grade_material.set_shader_parameter("night", clock.darkness())
	grade_material.set_shader_parameter("clock_time", world.elapsed)
	var active_area := rect.grow(64)
	for item in decor:
		if active_area.has_point(item.sprite.position):
			item.sprite.region_rect = Rect2(
				int(world.elapsed * 4.0) % 4 * item.width, 0, item.width, item.height
			)
	var positions := PackedVector2Array()
	var powers := PackedFloat32Array()
	for beacon in world.beacons:
		positions.append(beacon.position - Vector2(0, 19))
		if active_area.has_point(beacon.position):
			var lit: bool = beacon.lit or clock.darkness() > 0.05
			beacon.sprite.region_rect = Rect2(
				int(world.elapsed * 6.0) % 4 * 12, 28 if lit else 0, 12, 28
			)
		# Street lamps light automatically at dusk; quest-lit lamps remain lit.
		powers.append(1.0 if beacon.lit or clock.darkness() > 0.05 else 0.0)
	positions.append(world.hero.position - Vector2(0, 10))
	powers.append(0.7)
	grade_material.set_shader_parameter("lamps", positions)
	if not lights_enabled:
		powers.fill(0)
	grade_material.set_shader_parameter("powers", powers)
	world.get_node("Sunshine").modulate.a = 1.0 - clock.darkness() * 0.94
	moon.queue_redraw()


func state() -> Dictionary:
	var lit: Array[bool] = []
	for beacon in world.beacons:
		lit.append(beacon.lit)
	return {
		"x": world.hero.position.x,
		"y": world.hero.position.y,
		"facing": world.hero.facing,
		"equipped": world.hero.equipped,
		"hour": clock.hour,
		"day": clock.day,
		"play_seconds": play_seconds,
		"intro_done": intro_done,
		"beacons": lit
	}


func save_game(automatic: bool = false) -> bool:
	if disabled_io or not session_started:
		return false
	var saved := store.save(state())
	if saved:
		cached_save = state()
		autosave_clock = 0
		toast("Автосохранение · готово" if automatic else "Игра сохранена")
	else:
		toast(store.last_error, 8)
	return saved


func toast(text: String, duration: float = 3.0) -> void:
	notice.text = text
	notice_time = duration
	notice.show()


func continue_game() -> void:
	var data := store.load_game()
	if data.is_empty():
		toast("Сохранение не удалось прочитать. Можно начать новую игру.", 8)
		show_menu("main")
		return
	apply_state(data)
	world.resume()
	if store.recovered:
		toast("Восстановлена резервная копия сохранения.", 6)


func apply_state(data: Dictionary) -> void:
	world.hero.position = safe_position(Vector2(data.x, data.y))
	world.hero.facing = int(data.facing)
	world.hero.equipped = int(data.equipped)
	world.hero.update_tool()
	world.hero.timer = 0
	world.hero.state = "idle"
	clock.hour = data.hour
	clock.day = int(data.day)
	play_seconds = data.play_seconds
	intro_done = data.intro_done
	for i in range(world.beacons.size()):
		world.beacons[i].lit = data.beacons[i]
	world.camera.position = world.hero.position
	world.camera.reset_smoothing()
	autosave_clock = 0
	session_started = true


func safe_position(candidate: Vector2) -> Vector2:
	var foot := candidate - Vector2(0, 3)
	for solid in world.map.solids:
		var r: Array = solid.rect
		var rect := Rect2(r[0], r[1], r[2], r[3])
		var closest := foot.clamp(rect.position, rect.end)
		# Match actor.gd's 4px circle, including clear space around rectangle corners.
		# Do not reject legitimate physics contacts using a larger square margin.
		if foot.distance_squared_to(closest) < 16.0:
			return Vector2(world.map.spawn[0], world.map.spawn[1])
	return candidate


func request_new() -> void:
	if not cached_save.is_empty() or session_started:
		confirm(
			"Начать заново?\nТекущее путешествие будет заменено\nпосле вступления.",
			start_new,
			"main"
		)
	else:
		start_new()


func start_new() -> void:
	replaying = false
	show_intro()


func show_intro(replay: bool = false) -> void:
	replaying = replay
	story_page = 0
	world.mode = "intro"
	_render_story()


func _render_story() -> void:
	_clear()
	world.mode = "intro"
	var image := TextureRect.new()
	image.texture = STORY_ART[story_page]
	image.position = Vector2(0, 0)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.set_deferred("size", Vector2(640, 235))
	image.clip_contents = true
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	world.menu_root.add_child(image)
	var dark := ColorRect.new()
	dark.color = Color("0c1520")
	dark.position = Vector2(0, 235)
	dark.size = Vector2(640, 125)
	world.menu_root.add_child(dark)
	var title: Label = world._label(STORY[story_page][0], 12, Color("e4bf7f"))
	title.position = Vector2(34, 247)
	world.menu_root.add_child(title)
	story_text = RichTextLabel.new()
	story_text.position = Vector2(34, 271)
	story_text.size = Vector2(572, 59)
	story_text.add_theme_font_size_override("normal_font_size", 14)
	story_text.add_theme_color_override("default_color", Color("eee8d8"))
	story_text.scroll_active = false
	story_text.text = STORY[story_page][1]
	story_text.visible_characters = 0
	story_clock = 0
	world.menu_root.add_child(story_text)
	var footer: Label = world._label(
		(
			"Z / ENTER — дальше     X — весь текст     ESC — пропустить       %d / 4"
			% (story_page + 1)
		),
		9,
		Color("a6b8b4")
	)
	footer.position = Vector2(34, 340)
	world.menu_root.add_child(footer)
	get_viewport().gui_release_focus()


func complete_intro() -> void:
	if replaying:
		show_menu("main")
		return
	var fresh := {
		"x": world.map.spawn[0],
		"y": world.map.spawn[1],
		"facing": 0,
		"equipped": 0,
		"hour": Clock.START_HOUR,
		"day": 1,
		"play_seconds": 0,
		"intro_done": true,
		"beacons": [false, false, false, false, false, false]
	}
	apply_state(fresh)
	world.resume()
	if not disabled_io:
		save_game()


func handle(event: InputEvent) -> bool:
	if world.mode != "intro":
		return false
	if event.is_action_pressed("pause"):
		confirm("Пропустить предысторию?", complete_intro, "intro")
	elif event.is_action_pressed("cancel"):
		story_clock = 10000
	elif event.is_action_pressed("interact"):
		if story_text.visible_characters < story_text.get_total_character_count():
			story_clock = 10000
		elif story_page < STORY.size() - 1:
			story_page += 1
			_render_story()
		else:
			complete_intro()
	return true


func _clear() -> void:
	world.menu_root.show()
	for child in world.menu_root.get_children():
		world.menu_root.remove_child(child)
		child.queue_free()


func confirm(text: String, callback: Callable, origin: String) -> void:
	confirm_action = callback
	confirm_return = origin
	_clear()
	world.mode = "confirm"
	_shade()
	var box := VBoxContainer.new()
	box.position = Vector2(170, 104)
	box.add_theme_constant_override("separation", 12)
	world.menu_root.add_child(box)
	box.add_child(world._label(text, 15))
	var no: Button = world._make_button("Отмена", cancel_confirm)
	box.add_child(no)
	box.add_child(world._make_button("Подтвердить", func(): confirm_action.call()))
	no.grab_focus()


func cancel_confirm() -> void:
	if confirm_return == "intro":
		_render_story()
	else:
		show_menu(confirm_return)


func _shade() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.065, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.menu_root.add_child(shade)


func show_menu(which: String) -> void:
	_clear()
	world.mode = which
	_shade()
	var title: Label = world._label("ФОНАРЩИК", 31)
	title.position = Vector2(30, 40)
	world.menu_root.add_child(title)
	var subtitle: Label = world._label("Т И Х А Я   Д О Л И Н А", 11, Color("e4bf7f"))
	subtitle.position = Vector2(32, 82)
	world.menu_root.add_child(subtitle)
	var picture := TextureRect.new()
	picture.texture = STORY_ART[0]
	picture.position = Vector2(32, 113)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_deferred("size", Vector2(316, 178))
	picture.clip_contents = true
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	world.menu_root.add_child(picture)
	var caption: Label = world._label("У каждой тропы есть память.", 11, Color("b7c7bf"))
	caption.position = Vector2(32, 305)
	world.menu_root.add_child(caption)
	var box := VBoxContainer.new()
	box.position = Vector2(380, 30)
	box.custom_minimum_size.x = 228
	box.add_theme_constant_override("separation", 6)
	world.menu_root.add_child(box)
	var first: Control
	if which == "main":
		box.add_child(world._label("ПУТЕШЕСТВИЕ", 12, Color("e4bf7f")))
		if not cached_save.is_empty():
			first = _button(box, "Продолжить", continue_game)
			box.add_child(
				world._label("День %d · %s" % [int(cached_save.day), _saved_period()], 10)
			)
		var new_button := _button(
			box, "Новая игра" if not cached_save.is_empty() else "Играть", request_new
		)
		if first == null:
			first = new_button
		_button(box, "Предыстория", show_intro.bind(true))
		_button(box, "Настройки", world._open_submenu.bind("settings", "main"))
		_button(box, "Управление", world._open_submenu.bind("controls", "main"))
		_button(box, "Выйти", request_quit)
	elif which == "pause":
		box.add_child(
			world._label(
				"День %d · %s · %s" % [clock.day, clock.display_time(), clock.period()],
				11,
				Color("e4bf7f")
			)
		)
		first = _button(box, "Продолжить", world.resume)
		_button(box, "Сохранить игру", func(): save_game())
		_button(box, "Настройки", world._open_submenu.bind("settings", "pause"))
		_button(box, "Управление", world._open_submenu.bind("controls", "pause"))
		_button(box, "Главное меню", return_to_main)
		_button(box, "Сохранить и выйти", save_and_quit)
	elif which == "settings":
		box.position.y = 18
		box.add_theme_constant_override("separation", 3)
		first = _settings(box)
	else:
		box.add_child(world._label("УПРАВЛЕНИЕ", 12, Color("e4bf7f")))
		(
			box
			. add_child(
				(
					world
					. _label(
						"WASD / стрелки — идти\nShift — бежать\nZ / Enter — взаимодействие\nX / J — взмах оружием\nQ / Tab — предмет\nПробел — свет фонаря\nC / Esc — пауза и сохранение\nF3 — коллизии\n\nДиалог: Z — дальше\nX — показать текст",
						11
					)
				)
			)
		)
		first = _button(box, "Назад", func(): show_menu(world.returning_to))
	first.grab_focus()


func _saved_period() -> String:
	var saved_clock := Clock.new()
	saved_clock.hour = cached_save.hour
	return saved_clock.period()


func _button(box: VBoxContainer, text: String, callback: Callable) -> Button:
	var button: Button = world._make_button(text, callback)
	button.custom_minimum_size = Vector2(228, 29)
	box.add_child(button)
	return button


func _settings(box: VBoxContainer) -> Control:
	box.add_child(world._label("НАСТРОЙКИ", 12, Color("e4bf7f")))
	var volume := HSlider.new()
	volume.min_value = -40
	volume.max_value = 0
	volume.value = AudioServer.get_bus_volume_db(0)
	volume.custom_minimum_size = Vector2(220, 18)
	volume.value_changed.connect(world._set_volume)
	box.add_child(world._label("Громкость", 10))
	box.add_child(volume)
	var ambience := CheckButton.new()
	ambience.text = "Звуки леса"
	ambience.button_pressed = world.ambience_enabled
	ambience.add_theme_font_size_override("font_size", 12)
	ambience.toggled.connect(world._set_ambience)
	box.add_child(ambience)
	var leaves := CheckButton.new()
	leaves.text = "Листья и светлячки"
	leaves.button_pressed = world.particles_enabled
	leaves.add_theme_font_size_override("font_size", 12)
	leaves.toggled.connect(world._set_leaves)
	box.add_child(leaves)
	box.add_child(world._label("Автосохранение", 10))
	var interval := OptionButton.new()
	interval.add_theme_font_size_override("font_size", 12)
	for label in [
		"Выключено", "Каждую минуту", "Каждые 2 минуты", "Каждые 5 минут", "Каждые 10 минут"
	]:
		interval.add_item(label)
	interval.select([0, 60, 120, 300, 600].find(autosave_seconds))
	interval.item_selected.connect(
		func(index: int):
			autosave_seconds = [0, 60, 120, 300, 600][index]
			autosave_clock = 0
			persist_options()
	)
	box.add_child(interval)
	box.add_child(world._label("Полные сутки", 10))
	var speed := OptionButton.new()
	speed.add_theme_font_size_override("font_size", 12)
	for label in ["12 минут", "24 минуты", "48 минут", "Остановить время"]:
		speed.add_item(label)
	speed.select(
		(
			3
			if not clock.enabled
			else (0 if clock.cycle_minutes < 18 else (1 if clock.cycle_minutes < 36 else 2))
		)
	)
	speed.item_selected.connect(
		func(index: int):
			clock.enabled = index != 3
			if index < 3:
				clock.cycle_minutes = [12.0, 24.0, 48.0][index]
			persist_options()
	)
	box.add_child(speed)
	_button(box, "Окно / полный экран", world._toggle_fullscreen)
	_button(box, "Назад", func(): show_menu(world.returning_to))
	return volume


func persist_options() -> void:
	if disabled_io:
		return
	world.settings.set_value("save", "interval", autosave_seconds)
	world.settings.set_value("time", "minutes", clock.cycle_minutes)
	world.settings.set_value("time", "enabled", clock.enabled)
	world._save_settings()


func return_to_main() -> void:
	if session_started and not disabled_io and not save_game():
		return
	show_menu("main")


func request_quit() -> void:
	if session_started:
		save_and_quit()
	else:
		get_tree().quit()


func save_and_quit() -> void:
	if not disabled_io and not save_game():
		return
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world != null:
		request_quit()
