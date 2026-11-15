extends Node2D
# gdlint: disable=max-line-length
## All map geometry is loaded from the same manifest as the art assembly.
const Actor = preload("res://scripts/actor.gd")
const Capture = preload("res://scripts/capture.gd")
const A = "res://assets/ninja/"
var map: Dictionary
var hero: CharacterBody2D
var traveller: CharacterBody2D
var actors := Node2D.new()
var camera := Camera2D.new()
var mode := "main"
var elapsed := 0.0
var ability_cooldown := 0.0
var pulse := -1.0
var pulse_center := Vector2.ZERO
var particles_enabled := true
var ambience_enabled := true
var debug_collision := false
var body := StaticBody2D.new()
var overlays := Node2D.new()
var ui := CanvasLayer.new()
var menu_root: Control
var dialog_root: Control
var dialogue_text: RichTextLabel
var portrait: TextureRect
var interact_button: Button
var dialog_page := 0
var type_clock := 0.0
var dialogue := [
	"Ты тоже услышал колокол? Здесь он молчит уже много лет. А сегодня утром... один удар. Со стороны озера.",
	"Раньше я зажигал огни на лесной тропе. Люди возвращались по ним домой. Потом однажды не вернулся мой брат.",
	"Я искал его за дальними соснами. Нашёл только фонарь — такой же, как у тебя. Внутри всё ещё было тепло.",
	"Старики говорят: лес не забирает тех, кто помнит дорогу. Но дорога тоже должна помнить человека.",
	"Попробуй зажечь огни у площади и на ферме. Не ради старой легенды. Ради того, кто однажды увидит их из темноты.",
	"А если у озера услышишь второй удар... не спеши обнажать меч. Иногда домой возвращаются совсем тихо."
]
var beacons: Array[Dictionary] = []
var animated: Array[Dictionary] = []
var fireflies: Array[Vector3] = []
var leaves: Array[Vector3] = []
var tone_player := AudioStreamPlayer.new()
var ambience_player := AudioStreamPlayer.new()
var settings := ConfigFile.new()
var returning_to := "main"
var capture_path := ""
var capture_running := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_path = arg.trim_prefix("--capture-dir=")
	capture_running = not capture_path.is_empty()
	seed(317)
	_configure_input()
	_load_settings()
	map = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/map.json"))
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/world/ground.png")
	ground.centered = false
	ground.z_index = -10
	add_child(ground)
	var shadows := Sprite2D.new()
	shadows.texture = load("res://assets/world/sun_shadows.png")
	shadows.centered = false
	shadows.z_index = -5
	add_child(shadows)
	var sunshine := ColorRect.new()
	sunshine.size = Vector2(map.size[0], map.size[1])
	sunshine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sunshine.z_index = 80
	var sun_material := ShaderMaterial.new()
	sun_material.shader = load("res://scripts/sunlight.gdshader")
	sunshine.material = sun_material
	add_child(sunshine)
	actors.y_sort_enabled = true
	add_child(actors)
	body.collision_layer = 1
	add_child(body)
	for item in map.solids:
		var values: Array = item.rect
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(values[2], values[3])
		shape.shape = rect
		shape.position = Vector2(values[0], values[1]) + rect.size / 2.0
		shape.set_meta("kind", item.kind)
		body.add_child(shape)
	var sway_shader := Shader.new()
	sway_shader.code = "shader_type canvas_item; uniform float phase=0.0; void vertex(){ VERTEX.x += sin(TIME*1.1+phase)*0.7*(1.0-UV.y); }"
	for item in map.objects:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/world/" + item.art)
		# Sort from feet while keeping the image origin exactly on its manifest.
		sprite.position = Vector2(
			item.position[0] + item.size[0] / 2.0, item.position[1] + item.sort_y
		)
		sprite.offset = Vector2(0, item.size[1] / 2.0 - item.sort_y)
		sprite.set_meta("art", item.art)
		if item.sway:
			var sway_material := ShaderMaterial.new()
			sway_material.shader = sway_shader
			sway_material.set_shader_parameter("phase", float(item.position[0]) * 0.15)
			sprite.material = sway_material
		actors.add_child(sprite)
	for item in map.animations:
		_add_animated(item.kind, Vector2(item.position[0], item.position[1]))
	hero = spawn_actor(Vector2(map.spawn[0], map.spawn[1]), "", true)
	traveller = spawn_actor(Vector2(map.wanderer[0], map.wanderer[1]))
	for data in [
		["fox", 340, 560],
		["rabbit", 590, 800],
		["rabbit", 930, 800],
		["fox", 1040, 780],
		["rabbit", 610, 295],
		["fox", 250, 290],
		["rabbit", 1050, 400],
		["rabbit", 380, 880],
		["fox", 1300, 750],
		["rabbit", 210, 720],
		["rabbit", 780, 210]
	]:
		spawn_actor(Vector2(data[1], data[2]), data[0])
	camera.position = hero.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(map.size[0])
	camera.limit_bottom = int(map.size[1])
	add_child(camera)
	overlays.set_script(preload("res://scripts/atmosphere.gd"))
	overlays.world = self
	overlays.z_index = 100
	add_child(overlays)
	for i in range(80):
		leaves.append(Vector3(randf() * 1536, randf() * 1152, randf() * TAU))
	for i in range(60):
		fireflies.append(Vector3(randf() * 1536, randf() * 1152, randf() * TAU))
	add_child(tone_player)
	add_child(ambience_player)
	ambience_player.stream = load("res://assets/world/woodland.wav")
	ambience_player.volume_db = -10.0
	(ambience_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	(ambience_player.stream as AudioStreamWAV).loop_end = int(
		ambience_player.stream.get_length() * 22050
	)
	if ambience_enabled and not capture_running and DisplayServer.get_name() != "headless":
		ambience_player.play()
	_build_ui()
	show_menu("main")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_path = arg.trim_prefix("--capture-dir=")
	if not capture_path.is_empty():
		capture_running = true
		get_node(".").call_deferred("run_capture")


func _configure_input() -> void:
	var bindings := {
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"up": [KEY_W, KEY_UP],
		"down": [KEY_S, KEY_DOWN],
		"interact": [KEY_Z, KEY_ENTER],
		"cancel": [KEY_X],
		"pause": [KEY_ESCAPE, KEY_C],
		"attack": [KEY_J],
		"ability": [KEY_SPACE],
		"equip": [KEY_Q, KEY_TAB],
		"run": [KEY_SHIFT],
		"collision": [KEY_F3]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _load_settings() -> void:
	if settings.load("user://valley-settings.cfg") == OK:
		particles_enabled = settings.get_value("visual", "leaves", true)
		ambience_enabled = settings.get_value("audio", "ambience", true)
		AudioServer.set_bus_volume_db(0, settings.get_value("audio", "volume", -6.0))
	else:
		AudioServer.set_bus_volume_db(0, -6.0)


func _save_settings() -> void:
	settings.set_value("visual", "leaves", particles_enabled)
	settings.set_value("audio", "ambience", ambience_enabled)
	settings.set_value("audio", "volume", AudioServer.get_bus_volume_db(0))
	settings.save("user://valley-settings.cfg")


func spawn_actor(at: Vector2, species: String = "", controlled: bool = false) -> CharacterBody2D:
	var actor := Actor.new()
	actor.position = at
	actor.species = species
	actor.world = self
	actor.player_controlled = controlled
	actors.add_child(actor)
	return actor


func _add_animated(kind: String, at: Vector2) -> void:
	if kind == "lantern":
		var beacon_sprite := Sprite2D.new()
		beacon_sprite.texture = load("res://assets/world/lantern.png")
		beacon_sprite.position = at + Vector2(8, 15)
		beacon_sprite.offset = Vector2(0, -14)
		actors.add_child(beacon_sprite)
		beacons.append({"position": at + Vector2(8, 15), "lit": false})
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(
		(
			A
			+ (
				"Backgrounds/Animated/Water Ripples/SpriteSheet16x16.png"
				if kind == "ripple"
				else "Backgrounds/Animated/Flower/SpriteSheet16x16.png"
			)
		)
	)
	sprite.region_enabled = true
	sprite.position = at
	sprite.centered = false
	# Flowers/ripples belong to the floor, not above the hero.
	sprite.z_index = -1
	actors.add_child(sprite)
	if kind == "ripple":
		sprite.modulate.a = 0.25
	animated.append(
		{
			"sprite": sprite,
			"offset": randf() * 4.0,
			"frame_size": Vector2(16, 16) if kind == "ripple" else Vector2(5, 8)
		}
	)


func _process(delta: float) -> void:
	if mode == "play" or mode == "main":
		elapsed += delta
		for item in animated:
			item.sprite.region_rect = Rect2(
				Vector2(int(elapsed * 4.0 + item.offset) % 4 * item.frame_size.x, 0),
				item.frame_size
			)
	if mode == "play":
		ability_cooldown = maxf(0.0, ability_cooldown - delta)
		camera.position = hero.position
		if pulse >= 0.0:
			pulse += delta
			if pulse > 1.2:
				pulse = -1.0
	if mode == "dialogue":
		type_clock += delta * 32.0
		var before := dialogue_text.visible_characters
		dialogue_text.visible_characters = mini(
			int(type_clock), dialogue_text.get_total_character_count()
		)
		if before < dialogue_text.visible_characters and int(type_clock) % 3 == 0:
			play_tone(170.0 + float(dialog_page) * 24.0, 0.016, 0.035)
	interact_button.visible = mode == "play" and interactable()
	overlays.queue_redraw()


func clear_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func interactable() -> bool:
	if hero.position.distance_to(traveller.position) < 34.0:
		return true
	for beacon in beacons:
		if hero.position.distance_to(beacon.position) < 26.0 and not beacon.lit:
			return true
	return false


func interact() -> void:
	if hero.position.distance_to(traveller.position) < 34.0:
		begin_dialogue()
		return
	for beacon in beacons:
		if hero.position.distance_to(beacon.position) < 26.0:
			beacon.lit = true
			play_tone(730.0, 0.25, 0.12)
			return


func use_ability() -> void:
	if ability_cooldown > 0.0 or hero.timer > 0.0:
		return
	ability_cooldown = 3.0
	pulse = 0.0
	pulse_center = hero.position
	hero.state = "ability"
	hero.timer = 0.65
	play_tone(523.25, 0.5, 0.14)
	for beacon in beacons:
		if hero.position.distance_to(beacon.position) < 115.0:
			beacon.lit = true
	for actor in actors.get_children():
		if (
			actor is CharacterBody2D
			and not actor.species.is_empty()
			and actor.position.distance_to(hero.position) < 125.0
		):
			actor.wander = hero.position.direction_to(actor.position)
			actor.flee_time = 3.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("collision"):
		debug_collision = not debug_collision
		get_tree().debug_collisions_hint = debug_collision
		return
	if mode == "dialogue":
		if event.is_action_pressed("cancel"):
			type_clock = float(dialogue_text.get_total_character_count())
		elif event.is_action_pressed("interact"):
			if dialogue_text.visible_characters < dialogue_text.get_total_character_count():
				type_clock = float(dialogue_text.get_total_character_count())
			elif dialog_page + 1 < dialogue.size():
				dialog_page += 1
				_update_dialogue()
			else:
				mode = "play"
				dialog_root.hide()
		elif event.is_action_pressed("pause"):
			mode = "play"
			dialog_root.hide()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("cancel") and mode != "play":
		if mode == "play":
			show_menu("pause")
		elif mode == "pause":
			resume()
		elif mode == "settings" or mode == "controls":
			show_menu(returning_to)
		return
	if mode != "play":
		if event.is_action_pressed("interact"):
			var focused := get_viewport().gui_get_focus_owner()
			if focused is BaseButton:
				if focused.toggle_mode:
					focused.button_pressed = not focused.button_pressed
				focused.pressed.emit()
		return
	if event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("attack") or event.is_action_pressed("cancel"):
		hero.start_attack()
	elif event.is_action_pressed("ability"):
		use_ability()
	elif event.is_action_pressed("equip"):
		hero.equipped = (hero.equipped + 1) % Actor.TOOLS.size()
		hero.update_tool()


func play_tone(frequency: float, duration: float, volume: float) -> void:
	if capture_running or DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var sample_count := int(duration * 22050)
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / 22050.0
		var envelope := sin(PI * t / duration) * exp(-t * 4.0)
		var sample := int(sin(t * frequency * TAU) * volume * envelope * 32700.0)
		samples.encode_s16(i * 2, sample)
	stream.data = samples
	tone_player.stream = stream
	tone_player.play()


func _panel_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _label(text: String, size: int, color: Color = Color("eee6cc")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


func _make_button(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(192, 29)
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", Color("dedbc0"))
	node.add_theme_color_override("font_hover_color", Color("fff1be"))
	node.add_theme_stylebox_override("normal", _panel_style(Color("1f3430"), Color("52654c")))
	node.add_theme_stylebox_override("hover", _panel_style(Color("3e5140"), Color("c6b779")))
	node.add_theme_stylebox_override("focus", _panel_style(Color(0, 0, 0, 0), Color("dac68d"), 2))
	node.add_theme_stylebox_override("pressed", _panel_style(Color("55644a"), Color("f3d695")))
	node.pressed.connect(callback)
	return node


func _build_ui() -> void:
	add_child(ui)
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu_root)
	dialog_root = PanelContainer.new()
	dialog_root.position = Vector2(32, 244)
	dialog_root.size = Vector2(576, 98)
	dialog_root.add_theme_stylebox_override(
		"panel", _panel_style(Color("101c20"), Color("e6dfc4"), 2)
	)
	ui.add_child(dialog_root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	dialog_root.add_child(row)
	portrait = TextureRect.new()
	portrait.texture = load(A + "Actor/Character/Master/Faceset.png")
	portrait.custom_minimum_size = Vector2(60, 60)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(_label("СТРАННИК", 10, Color("d0b676")))
	dialogue_text = RichTextLabel.new()
	dialogue_text.custom_minimum_size = Vector2(440, 46)
	dialogue_text.add_theme_font_size_override("normal_font_size", 14)
	dialogue_text.add_theme_color_override("default_color", Color("f6edda"))
	dialogue_text.scroll_active = false
	column.add_child(dialogue_text)
	var help := _label("Z  дальше      X  пропустить печать", 9, Color("a0ada1"))
	column.add_child(help)
	dialog_root.hide()
	interact_button = _make_button("Z", interact)
	interact_button.focus_mode = Control.FOCUS_NONE
	interact_button.custom_minimum_size = Vector2(34, 30)
	interact_button.position = Vector2(580, 302)
	interact_button.size = Vector2(34, 30)
	ui.add_child(interact_button)
	interact_button.hide()


func show_menu(which: String) -> void:
	mode = which
	menu_root.show()
	for child in menu_root.get_children():
		menu_root.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.075, 0.71)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(shade)
	var brand := VBoxContainer.new()
	brand.position = Vector2(40, 80)
	brand.add_theme_constant_override("separation", 8)
	menu_root.add_child(brand)
	brand.add_child(_label("ТИХАЯ ДОЛИНА", 11, Color("d1ba7c")))
	brand.add_child(_label("ФОНАРЩИК", 32))
	brand.add_child(_label("У каждой тропы есть память.", 12, Color("b4c5ac")))
	brand.add_child(_label("", 16))
	brand.add_child(_label("Исследуй. Слушай. Зажигай огни.", 11, Color("a2b39d")))
	brand.add_child(
		_label(
			"Ninja Adventure · Pixel-boy & AAA\nОригинальная история и карта", 9, Color("8c9e8b")
		)
	)
	var box := VBoxContainer.new()
	box.position = Vector2(398, 54)
	box.add_theme_constant_override("separation", 7)
	menu_root.add_child(box)
	box.add_child(
		_label(
			{
				"main": "ДОБРО ПОЖАЛОВАТЬ",
				"pause": "ПРИВАЛ",
				"settings": "НАСТРОЙКИ",
				"controls": "УПРАВЛЕНИЕ"
			}[which],
			12,
			Color("d1ba7c")
		)
	)
	box.add_child(HSeparator.new())
	var first: Control
	if which == "main" or which == "pause":
		first = _make_button("Войти в долину" if which == "main" else "Продолжить", resume)
		box.add_child(first)
		box.add_child(_make_button("Настройки", _open_submenu.bind("settings", which)))
		box.add_child(_make_button("Управление", _open_submenu.bind("controls", which)))
		if which == "pause":
			box.add_child(_make_button("Главное меню", func(): show_menu("main")))
		box.add_child(_make_button("Выйти", func(): get_tree().quit()))
	elif which == "settings":
		var sound := CheckButton.new()
		sound.text = "Звуки леса"
		sound.button_pressed = ambience_enabled
		sound.add_theme_font_size_override("font_size", 13)
		sound.toggled.connect(_set_ambience)
		box.add_child(sound)
		first = sound
		box.add_child(_label("Громкость", 11))
		var volume := HSlider.new()
		volume.min_value = -40
		volume.max_value = 0
		volume.value = AudioServer.get_bus_volume_db(0)
		volume.custom_minimum_size = Vector2(192, 18)
		volume.value_changed.connect(_set_volume)
		box.add_child(volume)
		var leaves_toggle := CheckButton.new()
		leaves_toggle.text = "Листья и светлячки"
		leaves_toggle.add_theme_font_size_override("font_size", 13)
		leaves_toggle.button_pressed = particles_enabled
		leaves_toggle.toggled.connect(_set_leaves)
		box.add_child(leaves_toggle)
		var full := _make_button("Окно / полный экран", _toggle_fullscreen)
		box.add_child(full)
		box.add_child(_make_button("Назад", func(): show_menu(returning_to)))
	else:
		var guide := _label(
			"WASD / стрелки — идти\nShift — бежать\nZ / Enter — взаимодействие\nX / J — взмах оружием\nQ / Tab — сменить предмет\nПробел — свет фонаря\nC / Esc — пауза\nF3 — коллизии\n\nВ диалоге: Z — дальше,\nX — показать строку целиком",
			11
		)
		box.add_child(guide)
		first = _make_button("Назад", func(): show_menu(returning_to))
		box.add_child(first)
	first.grab_focus()
	var footer := _label("Z / ENTER  выбрать     X  назад", 9, Color("b6b695"))
	footer.position = Vector2(40, 326)
	menu_root.add_child(footer)


func resume() -> void:
	mode = "play"
	menu_root.hide()
	get_viewport().gui_release_focus()


func begin_dialogue() -> void:
	mode = "dialogue"
	dialog_page = 0
	dialog_root.show()
	_update_dialogue()


func _update_dialogue() -> void:
	type_clock = 0.0
	dialogue_text.text = "* " + dialogue[dialog_page]
	dialogue_text.visible_characters = 0


func run_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var driver: Node = Capture.new()
	add_child(driver)
	await driver.run(self, capture_path)
	driver.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	tone_player.stop()
	ambience_player.stop()
	# Release world shaders/canvas resources while the renderer is still running.
	# A tree-owned timer survives this node and quits only after queued deletion.
	get_tree().create_timer(0.15).timeout.connect(get_tree().quit)
	queue_free()


func _open_submenu(submenu: String, origin: String) -> void:
	returning_to = origin
	show_menu(submenu)


func _set_ambience(value: bool) -> void:
	ambience_enabled = value
	if value:
		ambience_player.play()
	else:
		ambience_player.stop()
	_save_settings()


func _set_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	_save_settings()


func _set_leaves(value: bool) -> void:
	particles_enabled = value
	_save_settings()


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
