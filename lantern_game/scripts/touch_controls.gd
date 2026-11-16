extends Control
# gdlint: disable=max-returns
## Analog stick with independent pointer ownership; never synthesizes arrow keys.
const ACTIONS = {"Z": "interact", "X": "cancel", "C": "pause", "L": "ability", "Q": "equip"}
const DEFAULT_POSITIONS = {
	"stick": Vector2(0.12, 0.79),
	"Z": Vector2(0.90, 0.79),
	"X": Vector2(0.80, 0.87),
	"C": Vector2(0.94, 0.60),
	"L": Vector2(0.82, 0.64),
	"Q": Vector2(0.72, 0.80)
}
const DEFAULT_RADII = {"stick": 47.0, "Z": 24.0, "X": 22.0, "C": 19.0, "L": 18.0, "Q": 18.0}
const DEADZONE = 0.16
var world: Node2D
var positions: Dictionary = DEFAULT_POSITIONS.duplicate(true)
var radii: Dictionary = DEFAULT_RADII.duplicate()
var movement := Vector2.ZERO
var knob := Vector2.ZERO
var stick_pointer := -1
var button_pointers: Dictionary = {}
var editing := false
var selected := "stick"
var drag_pointer := -1
var drag_offset := Vector2.ZERO
var original_positions: Dictionary = {}
var original_radii: Dictionary = {}
var size_slider: HSlider
var selected_label: Label
var last_mode := ""
var last_visible := false
var suppress_mouse_until := 0


func setup(owner_world: Node2D) -> void:
	world = owner_world
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_layout(world.settings)


func load_layout(config: ConfigFile) -> void:
	var saved_positions: Variant = config.get_value("touch", "positions", {})
	var saved_radii: Variant = config.get_value("touch", "radii", {})
	for key in DEFAULT_POSITIONS:
		var point: Variant = saved_positions.get(key) if saved_positions is Dictionary else null
		if point is Vector2 and point.is_finite():
			positions[key] = point.clamp(Vector2.ZERO, Vector2.ONE)
		var radius: Variant = saved_radii.get(key) if saved_radii is Dictionary else null
		if (radius is float or radius is int) and is_finite(float(radius)):
			radii[key] = clampf(
				float(radius), 32 if key == "stick" else 15, 65 if key == "stick" else 32
			)


func enabled() -> bool:
	return world.platform_options.mobile or world.platform_options.show_touch


func safe_rect() -> Rect2:
	var area := Rect2(Vector2.ZERO, Vector2(640, 360))
	if OS.has_feature("android") and DisplayServer.get_name() != "headless":
		var physical := Rect2(DisplayServer.get_display_safe_area())
		var transform := get_viewport().get_screen_transform().affine_inverse()
		var visible_area := area.intersection(transform * physical)
		if visible_area.size.x > 300 and visible_area.size.y > 200:
			area = visible_area
	return area.grow(-10)


func center(key: String) -> Vector2:
	var area := safe_rect()
	var point: Vector2 = area.position + positions[key] * area.size
	if not editing and world.mode in ["intro", "dialogue"] and key in ACTIONS:
		var index: int = ["C", "Z", "X", "L", "Q"].find(key)
		point = Vector2(606, 115 + index * 48)
	var radius: float = radii[key] + 2
	var lower := area.position + Vector2.ONE * radius
	if editing:
		lower.y = maxf(lower.y, 122 + radius)
	return point.clamp(lower, area.end - Vector2.ONE * radius)


func analog(displacement: Vector2, travel: float) -> Vector2:
	var raw := (displacement / maxf(travel, 1)).limit_length()
	var length := raw.length()
	if length <= DEADZONE:
		return Vector2.ZERO
	return raw.normalized() * ((length - DEADZONE) / (1 - DEADZONE))


func update_stick(point: Vector2) -> void:
	var travel: float = radii.stick * 0.58
	knob = (point - center("stick")).limit_length(travel)
	movement = analog(knob, travel)
	queue_redraw()


func release_all() -> void:
	movement = Vector2.ZERO
	knob = Vector2.ZERO
	stick_pointer = -1
	drag_pointer = -1
	button_pointers.clear()
	queue_redraw()


func pointer_down(index: int, point: Vector2) -> bool:
	if editing:
		if drag_pointer != -1:
			return false
		for key in radii:
			if center(key).distance_to(point) <= radii[key] + 5:
				selected = key
				drag_pointer = index
				drag_offset = center(key) - point
				_refresh_editor()
				return true
		return false
	if not enabled() or world.mode not in ["play", "intro", "dialogue"]:
		return false
	if world.mode == "play" and stick_pointer == -1:
		if center("stick").distance_to(point) <= radii.stick * 1.2:
			stick_pointer = index
			update_stick(point)
			return true
	for key in ACTIONS:
		if world.mode != "play" and key in ["L", "Q"]:
			continue
		if center(key).distance_to(point) <= radii[key] + 3:
			button_pointers[index] = key
			var event := InputEventAction.new()
			event.action = ACTIONS[key]
			event.pressed = true
			world._unhandled_input(event)
			queue_redraw()
			return true
	return false


func pointer_move(index: int, point: Vector2) -> bool:
	if editing and index == drag_pointer:
		var area := safe_rect()
		positions[selected] = ((point + drag_offset - area.position) / area.size).clamp(
			Vector2.ZERO, Vector2.ONE
		)
		# Persist the clamped center so repeated drags do not jump offscreen.
		positions[selected] = (center(selected) - area.position) / area.size
		queue_redraw()
		return true
	if index == stick_pointer:
		update_stick(point)
		return true
	return button_pointers.has(index)


func pointer_up(index: int) -> bool:
	var handled := button_pointers.has(index) or index == stick_pointer or index == drag_pointer
	button_pointers.erase(index)
	if index == stick_pointer:
		stick_pointer = -1
		movement = Vector2.ZERO
		knob = Vector2.ZERO
	if index == drag_pointer:
		drag_pointer = -1
	queue_redraw()
	return handled


func _input(event: InputEvent) -> void:
	var handled := false
	if event is InputEventScreenTouch:
		handled = (
			pointer_down(event.index, event.position)
			if event.pressed and not event.canceled
			else pointer_up(event.index)
		)
	elif event is InputEventScreenDrag:
		handled = pointer_move(event.index, event.position)
	elif editing and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		handled = pointer_down(1000, event.position) if event.pressed else pointer_up(1000)
	elif editing and event is InputEventMouseMotion and drag_pointer == 1000:
		handled = pointer_move(1000, event.position)
	if handled:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			suppress_mouse_until = Time.get_ticks_msec() + 100
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouse
		and event.device == -1
		and Time.get_ticks_msec() < suppress_mouse_until
	):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var shown: bool = editing or (enabled() and world.mode in ["play", "intro", "dialogue"])
	if last_mode != world.mode or shown != last_visible:
		release_all()
		last_mode = world.mode
		last_visible = shown
		queue_redraw()


func _draw() -> void:
	if (
		world == null
		or (not editing and (not enabled() or world.mode not in ["play", "intro", "dialogue"]))
	):
		return
	if editing or world.mode == "play":
		var base := center("stick")
		var radius: float = radii.stick
		draw_circle(base, radius, Color(0.06, 0.10, 0.14, 0.40))
		draw_circle(base, radius, Color(0.82, 0.89, 0.92, 0.40), false, 1.2, true)
		draw_circle(base, radius * 0.58, Color(0.75, 0.84, 0.88, 0.13), false, 0.8, true)
		draw_circle(base + knob, radius * 0.40, Color(0.57, 0.69, 0.74, 0.65))
		draw_circle(base + knob, radius * 0.40, Color(0.92, 0.95, 0.96, 0.55), false, 1, true)
	for key in ACTIONS:
		if not editing and world.mode != "play" and key in ["L", "Q"]:
			continue
		var point := center(key)
		var radius: float = radii[key]
		var pressed: bool = key in button_pointers.values()
		draw_circle(
			point,
			radius,
			Color(0.32, 0.44, 0.49, 0.70) if pressed else Color(0.06, 0.10, 0.14, 0.40)
		)
		draw_circle(point, radius, Color(0.82, 0.89, 0.92, 0.50), false, 1, true)
		var font := ThemeDB.fallback_font
		var font_size := int(radius * 0.85)
		var text_size := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(
			font,
			point + Vector2(-text_size.x * 0.5, font_size * 0.34),
			key,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.93, 0.95, 0.96, 0.85)
		)
	if editing:
		draw_circle(center(selected), radii[selected] + 5, Color("e4bf7f"), false, 1.5, true)


func begin_edit() -> void:
	release_all()
	original_positions = positions.duplicate(true)
	original_radii = radii.duplicate()
	world.foundation._clear()
	world.mode = "touch_layout"
	editing = true
	var panel := ColorRect.new()
	panel.size = Vector2(640, 116)
	panel.color = Color("0c1520")
	world.menu_root.add_child(panel)
	var title: Label = world._label("РАСПОЛОЖЕНИЕ И РАЗМЕР", 15, Color("e4bf7f"))
	title.position = Vector2(16, 8)
	world.menu_root.add_child(title)
	var hint: Label = world._label(
		"Перетащи стик или кнопку. Затем настрой размер выбранного элемента.", 10
	)
	hint.position = Vector2(16, 32)
	world.menu_root.add_child(hint)
	selected_label = world._label("", 11)
	selected_label.position = Vector2(350, 56)
	world.menu_root.add_child(selected_label)
	size_slider = HSlider.new()
	size_slider.position = Vector2(350, 82)
	size_slider.size = Vector2(270, 23)
	size_slider.step = 1
	size_slider.value_changed.connect(
		func(value: float):
			radii[selected] = value
			_refresh_editor(false)
	)
	world.menu_root.add_child(size_slider)
	for spec in [
		["Сохранить", finish_edit.bind(true)],
		["Отмена", finish_edit.bind(false)],
		["Сброс", reset_layout]
	]:
		var button: Button = world._make_button(spec[0], spec[1])
		button.custom_minimum_size = Vector2(100, 30)
		button.position = Vector2(16 + world.menu_root.get_meta("editor_buttons", 0) * 108, 70)
		world.menu_root.set_meta(
			"editor_buttons", world.menu_root.get_meta("editor_buttons", 0) + 1
		)
		world.menu_root.add_child(button)
	world.menu_root.set_meta("editor_buttons", 0)
	_refresh_editor()


func _refresh_editor(update_slider: bool = true) -> void:
	if is_instance_valid(size_slider):
		selected_label.text = (
			("Джойстик" if selected == "stick" else "Кнопка " + selected)
			+ " · радиус %d" % radii[selected]
		)
		if update_slider:
			size_slider.set_block_signals(true)
			size_slider.min_value = 32 if selected == "stick" else 15
			size_slider.max_value = 65 if selected == "stick" else 32
			size_slider.value = radii[selected]
			size_slider.set_block_signals(false)
	queue_redraw()


func reset_layout() -> void:
	positions = DEFAULT_POSITIONS.duplicate(true)
	radii = DEFAULT_RADII.duplicate()
	_refresh_editor()


func finish_edit(save: bool) -> void:
	editing = false
	release_all()
	if save:
		world.settings.set_value("touch", "positions", positions.duplicate(true))
		world.settings.set_value("touch", "radii", radii.duplicate())
		world._save_settings()
	else:
		positions = original_positions.duplicate(true)
		radii = original_radii.duplicate()
	world.platform_options.show_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()
